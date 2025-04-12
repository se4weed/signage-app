require 'anthropic'
require 'aws-sdk-bedrockruntime'
require 'logger'
require 'thread'
require_relative './schedule'

class Refiner
  def initialize(backend:, schedule:, track:, logger: Logger.new($stdout))
    @schedule = schedule
    @track = track
    @logger = logger
    @backend = backend

    @lock = Mutex.new

    @key = nil
    @session = nil
    @cache = MiniCache.new
    @captions = {}
    @log_io = nil
    @log = String.new
    switch_key
  end

  def generate_key(session)
    session ? "#{session.starts_at.strftime('%Y%m%d-%H%M%S')}-#{session.slug.gsub(/\//, ':')}" : 'intermission'
  end

  def switch_key(new = @schedule.current(track: @track))
    newkey = generate_key(new)
    return if newkey == @key
    @key = newkey
    @session = new
    @cache = MiniCache.new
    @captions = {}
    @log_io&.close
    @log_io = File.open("tmp/refiner_#{@key}.txt", "a+").tap do |io|
      io.sync = true
    end
    @log = begin
      @log_io.rewind
      @log_io.read
    end
  end

  def refine(caption, use_latest: false, &callback)
    @lock.synchronize do
      switch_key()
      if use_latest
        if caption.is_partial
          caption = @captions[caption.result_id]
          return unless caption
        else
          return unless @captions[caption.result_id]
        end
      else
        @captions[caption.result_id] = caption
      end

      sentences = caption.transcript.scan(/.+?(?:[^\d]\.|[\?!]$|\.\s+|\z)/)
      remainder = sentences.pop if !sentences.empty? && !sentences.last.match?(/(?:[^\d]\.|[\?!])\s*\z/)

      unless caption.is_partial
        sentences.push(remainder) if remainder
        remainder = nil
      end
      if sentences.empty?
        remainder = caption.transcript
      end
      p(sentences:,remainder:)

      full_sentence = caption.is_partial ? nil : (@cache.cache(caption.transcript) do
        dispatch_refinement(caption, caption.transcript, &callback)
      end)
      refined_sentences = sentences.map do |sentence|
        @cache.cache(sentence) do
          dispatch_refinement(caption, sentence, &callback)
        end
      end

      output = CaptionData.new(
        result_id: caption.result_id,
        is_partial: full_sentence&.result ? false : true,
        transcript: full_sentence&.result || [*refined_sentences.map(&:current), remainder].join(' '),
        source: :refiner,
      )

      callback.call(output)
      return unless full_sentence&.result

      o = "#{output.transcript}\n"
      @log_io&.write(o)
      @log << o
      @captions.delete(caption.result_id)
      callback.call(output)
    end
  end

  def dispatch_refinement(caption, sentence, &callback)
    @backend.dispatch(
      RefineInput.new(
        session: @session,
        log: @log,
        schedule: @schedule,
        sentence: sentence,
      ),
    ) do |data|
      self.refine(caption, use_latest: true, &callback)
    end
  end

end

class MiniCache
  MAX_SIZE = 1000

  def initialize
    @storage = {}
  end

  def cache(key, &block)
    if val = @storage[key]
      return val
    else
      # Remove oldest entry if we're at capacity
      if @storage.size >= MAX_SIZE
        @storage.shift # remove oldest entry
      end
      @storage[key] = block.call
    end
  end
end

RefineData = Struct.new(
  :input,
  :result,
) do
  def current
    result || input.sentence
  end
end

class RefineBackend
  Item = Data.define(:data, :callback)
  def initialize
    @queue = Queue.new
    @ths = nil
  end

  def threads = 2

  def start
    @ths = threads.times.map do
      Thread.new do
        while item = @queue.pop
          process(item)
        end
      end.tap { _1.abort_on_exception = true }
    end
  end

  def dispatch(input, &callback)
    data = RefineData.new(input, nil)
    @queue.push(Item.new(data:,callback:))
    data
  end
end

class AnthropicBackend < RefineBackend
  def initialize
    @anthropic = Anthropic::Client.new(
      access_token: ENV.fetch('ANTHROPIC_API_KEY'),
      anthropic_version: '2023-06-01',
    )
    super()
  end

  def process(item)
    p request: item.data
    response = @anthropic.messages(
      parameters: {
        model: 'claude-3-5-haiku-20241022', # 'claude-3-7-sonnet-20250219' ,
        system: item.data.input.system,
        messages: item.data.input.messages,
        max_tokens: 1000,
        temperature: 0,
      }
    )
    item.data.result = response.fetch("content").dig(0, 'text')
    p response: item.data
    item.callback.call(item.data)
    nil
  end
end

class BedrockBackend < RefineBackend
  def initialize
    @bedrock = Aws::BedrockRuntime::Client.new(region: 'ap-northeast-1')
    super()
  end

  def process(data)
    begin
      # TODO: Configure temperature etc
      invocation = @bedrock.invoke_model(
        model_id: 'anthropic.claude-3-5-sonnet-20240620-v1:0',
        content_type: 'application/json',
        accept: 'application/json',
        body: JSON.generate({
          anthropic_version: "bedrock-2023-05-31",
          max_tokens: 1000,
          messages: generate_messages(transcript),
        })
      )
    rescue Aws::BedrockRuntime::Errors::ServiceError => e
      p e
      return nil
    end

    # Block until entire response is ready
    response_io = invocation.body
    response = response_io.string

    data.result = JSON.parse(response)["content"].first["text"]
    nil
  end
end

class RefineInput
  def initialize(session:, log:, schedule:, sentence:)
    @session = session
    @log = log
    @schedule = schedule
    @sentence = sentence
  end

  attr_reader :session
  attr_reader :log
  attr_reader :schedule
  attr_reader :sentence

  def inspect
    "#<#{self.class.name} session=#{@session&.slug&.inspect} sentence=#{sentence.inspect}>"
  end

  def system
    [
      PROMPT,
      INSTRUCTION,
      attendee_information,
      session_information,
    ].join(?\n)
  end

  def reminder
    <<~EOF
      <reminder>
        #{session_information}
        #{INSTRUCTION}
      </reminder>
    EOF
  end

  def session_information
    return nil unless @session
    <<~EOF
      <session_information>
        <title>#{@session.title}</title>
        <abstract>
          #{@session.description}
        </abstract>
      </session_information>
      <speaker_information>
        #{@session.speakers.map do |speaker|
          "<name>#{speaker.name}</name><bio>#{speaker.bio}</bio>"
        end.join(?\n)}
      </speaker_information>
    EOF
  end

  def attendee_information
    <<~EOF
      <attendee_information>
        #{@schedule.known_speaker_names.map do |name|
          "<name>#{name}</name>"
        end.join(?\n)}
      </attendee_information>
    EOF
  end

  def messages
    [
      #*(unless @log.empty?
      #  [
      #    {
      #      role: "user",
      #      content: "<prior_transcription>\n#{@log}\n</prior_transcription>",
      #    },
      #    {
      #      role: "user",
      #      content: reminder,
      #    },
      #  ]
      #end),
      {
        role: "user",
        content: "<original_transcription>\n#{@sentence}\n</original_transcription>",
      },
    ].compact
  end

  PROMPT = <<~EOF
    You are a professional technical interpreter specializing in refining transcriptions of technical conferences on the Ruby programming language.
    You are expected to be familiar with the latest Ruby language ecosystem and innovation, such as Rubygems, Bundler, Ruby on Rails, RBS, parsers such as Prism/Lrama, and interpreter internals like YJIT, garbage collection, Ractor, async scheduler.

    Your task is to improve the quality of a English transcription of a technical talk session in the conference called RubyKaigi.

    The text given in <original_transcript> tag is a transcript of the talk session which you need to work on.
    Make the transcription in <original_transcript> more readable and accurate by following the instructions in <refine_instructions> tag. Output must be made in format described in the <output_instructions> tag.

    We provide several informations to understand the <original_transcript> and your mission in detail. You may use the informations below, and these informations are provided for your reference:
    - The <attendee_information> tag, which contains known names so you can ease correcting names.
    - The text given in <prior_transcription> tag. It is the transcript of the talk session prior to this conversation with you.
    - The <speaker_information> tag.
    - The <session_information> tag.
    - Any information inside <reminder> tag are reminders for you.
  EOF

  INSTRUCTION =<<~EOF
    <refine_instructions>
      - Remove filler words. We don't consider conjunctive a filler word, such as "so", "and".
      - Correct mistaken transcriptions, which can be often found for software names, library names, technology names, protocol names, Ruby language features, and well-known contributor names in the community.
      - Improve transcription correctness. You'll find mistakes like below, but not limited to these.
        - Ruby runtime version numbers such as 2.7, 3.0, 3.1, and so on. For instance, You need to correct "Rub33", "Ruby 33", "B 33" to "Ruby 3.3"
        - this conference name must be written as "RubyKaigi", instead of "Ruby Kaigi" or "RubyKagi"
      - You may use backquotes (``) if you find a code snippet (includes constant names, variable names, function names) in a transcript. But, multi-line code blocks are prohibited.
      - You are ONLY allowed to correct words and terms as requested above. Never skip any of the original transcription, and never add any contents that is not given in the original transcription.
      - Because you are an interpreter for deaf, you are NOT allowed to sprinkle your thoughts on output.
    </refine_instructions>

    <output_instructions>
      - Provide ONLY the refined transcription of the text in <original_transcription> tag.
      - Do NOT include any introductory text such as "Here is the improved transcription:".
      - The output should start directly with the refined English text.
      - If the output will be empty (in case the given transcription only consists of filler words), output "FILLER_ONLY" instead.
    </output_instructions>
  EOF
end
