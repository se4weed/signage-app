$stdout.sync = true
require 'socket'
require 'logger'
require 'fileutils'
require 'thread'

require 'aws-sdk-iotdataplane'
require 'aws-sdk-transcribestreamingservice'
require 'json'

require_relative './refiner'
require_relative './schedule'

# ffmpeg -i ... -vn -f s16le -ar 44100 -ac 1 - | ruby serve.rb a |& tee -a /tmp/serve
# ffmpeg -i udp://0.0.0.0:10000 -f mpegts -c:a pcm_s16le -vn -f s16le -ar 44100 -ac 1 - | ruby serve.rb a |& tee -a /tmp/serve
class StdinInput
  def initialize
    @on_data = proc { }
  end

  def on_data(&block)
    @on_data = block
    self
  end

  def start
    @th = Thread.new do
      $stdin.binmode
      $stderr.puts({binmode?: $stdin.binmode?}.inspect)
      until $stdin.eof?
        buf = $stdin.read(87500/2)
        @on_data.call buf
      end
    end.tap { _1.abort_on_exception = true }
  end
end

class TranscribeEngine
  def initialize()
    @client = Aws::TranscribeStreamingService::AsyncClient.new(region: 'ap-northeast-1')
    @input_stream = Aws::TranscribeStreamingService::EventStreams::AudioStream.new
    @output_stream = Aws::TranscribeStreamingService::EventStreams::TranscriptResultStream.new

    @output_stream.on_bad_request_exception_event do |exception|
      raise exception
    end

    @output_stream.on_event do |event|
      p event unless event.is_a?(Aws::TranscribeStreamingService::Types::TranscriptEvent)
    end
  end

  attr_reader :output_stream

  def feed_audio(audio_chunk)
    @input_stream.signal_audio_event_event(audio_chunk: audio_chunk)
    self
  rescue Seahorse::Client::Http2ConnectionClosedError
    @client.connection.errors.each do |e|
      p e
    end
    raise
  end

  def start
    vocabulary_name = ENV.fetch('TRANSCRIBE_VOCABULARY_NAME', 'rk_2025_words')
    language_model_name = ENV.fetch('TRANSCRIBE_LANGUAGE_MODEL_NAME', 'rk2025w')
    vocabulary_name = nil if vocabulary_name.empty?
    @client.start_stream_transcription(
      language_code: ENV.fetch('TRANSCRIBE_LANGUAGE_CODE', 'en-US'),

      enable_partial_results_stabilization: true,
      partial_results_stability: 'high',

      media_encoding: "pcm",
      media_sample_rate_hertz: 44100,

      vocabulary_name:,
      language_model_name:,

      input_event_stream_handler: @input_stream,
      output_event_stream_handler: @output_stream,
    )
  end

  def finish
    @input_stream.signal_end_stream
  end

  def on_transcript_event(&block)
    output_stream.on_transcript_event_event(&block)
    self
  end
end

CaptionData = Data.define(:result_id, :is_partial, :transcript, :source)

class GenericOutput
  def initialize()
    @data_lock = Mutex.new
    @data = {}
  end

  def feed_transcribe_event(event)
    captions = event.transcript.results.map do |result|
      CaptionData.new(
        result_id: result.result_id,
        is_partial: result.is_partial,
        transcript: result.alternatives[0]&.transcript,
        source: :transcribe,
      )
    end
    feed(*captions)
  end

  def feed(*captions)
    @data_lock.synchronize do
      captions.each do |caption|
        @data[caption.result_id] ||= {}
        @data[caption.result_id][caption.source] = caption if caption.transcript
      end
    end
  end

  def interval = 0.7

  def start
    @th = Thread.new do
      loop do
        begin
          data = nil
          @data_lock.synchronize do
            data = @data
            @data = {}
          end

          data.each do |k, captions|
            captions.each do |_source, caption|
              handle(caption)
            end
          end
        end
        sleep interval
      rescue => e
        warn e.full_message
        raise
      end
    end.tap { _1.abort_on_exception = true }
  end
end

class CopyOutput < GenericOutput
  def initialize(outputs:)
    @outputs = outputs
    super()
  end

  def feed(*captions)
    @outputs.each do |output|
      output.feed(*captions)
    end
  end

  def start; end
end

class RefinerOutput < GenericOutput
  def initialize(refiner, output)
    @refiner = refiner
    @output = output
    super()
  end

  def interval = 0.7

  def handle(caption)
    @refiner.refine(caption) do |output|
      @output.feed(output)
    end
  end
end

class IotDataPlaneOutput < GenericOutput
  def initialize(topic_prefix:, track:)
    @track = track
    @topic = "#{topic_prefix}/uplink/all/captions/#{track}"
    @iotdataplane = Aws::IoTDataPlane::Client.new(logger: Logger.new($stdout))

    @next_sequence_num = (Time.now.to_i - 1578000000) << 20
    @sequence_map = {}

    super()
  end

  def interval = 0.35

  def handle(caption)
    sequence = get_sequence_info(caption.source, caption.result_id)
    sequence.rounds[caption.source] ||= 0
    round = sequence.rounds[caption.source] += 1

    payload = {
      kind: "Caption",
      source: caption.source,
      track: @track,
      pid: $$,
      sequence_id: sequence.id,
      round:,
      result_id: sequence.result_id,
      is_partial: caption.is_partial,
      transcript: caption.transcript,
    }
    @iotdataplane.publish(
      topic: @topic,
      qos: 0,
      retain: false,
      payload: JSON.generate(payload),
    )

    unless caption.is_partial
      sequence.complete = true
      if @sequence_map.size > 1000
        @sequence_map.shift
      end
    end
  end

  SequenceInfo = Struct.new(:id, :result_id, :rounds, :complete)
  def get_sequence_info(source,result_id)
    @sequence_map[result_id] ||= begin
      @next_sequence_num = @next_sequence_num.succ & 9007199254740991 # Number.MAX_SAFE_INTEGER
      SequenceInfo.new(@next_sequence_num, result_id, {}, false)
    end
  end
end

class StderrOutput < GenericOutput
  def handle(caption)
    $stderr.puts caption.to_h.to_json
  end
end

class Watchdog
  NO_AUTO_RESTART_HOURS = ((0..9).to_a + (21..23).to_a).map { (_1 - 9).then { |jst|  jst < 0 ? 24+jst : jst } }

  def initialize(timeout: 1800, enabled: false)
    @timeout = timeout
    @last = Time.now.utc
    @enabled = enabled
  end

  attr_accessor :enabled

  def alive!
    @last = Time.now.utc
  end

  def start
    @th ||= Thread.new do
      loop do
        sleep 15
        now = Time.now.utc
        if (now - @last) > @timeout
          $stderr.puts "Watchdog engages!"
          next if NO_AUTO_RESTART_HOURS.include?(now.hour)
          if @enabled
            $stderr.puts "doggo shuts down this process"
            raise
          end
        end
      end
    end.tap { _1.abort_on_exception =  true }
  end
end


topic_prefix, track = ARGV[0,2]
warn "Usage for IoT: #$0 topic_prefix track" unless topic_prefix && track

watchdog = Watchdog.new(enabled: ARGV.delete('--watchdog'))
watchdog.start()

input = StdinInput.new
engine = TranscribeEngine.new
schedule = Schedule.new()

refine_backend = AnthropicBackend.new
refine_backend.start
refiner = Refiner.new(backend: refine_backend, schedule:, track:)

final_output = topic_prefix && track ? IotDataPlaneOutput.new(topic_prefix:, track:) : StderrOutput.new
refiner_output = RefinerOutput.new(refiner, final_output)
output = CopyOutput.new(outputs: [final_output, refiner_output])

FileUtils.mkdir_p 'tmp'

p schedule_current: schedule.current(track:)

input.on_data do |chunk|
  #p(now: Time.now, on_audio: chunk.bytesize)
  engine.feed_audio(chunk)
rescue => e
  warn e.full_message
  raise
end

engine.on_transcript_event do |e|
  watchdog&.alive!
  output.feed_transcribe_event(e)
rescue => e
  warn e.full_message
  raise
end
# TODO: graceful restart

begin
  refiner_output.start
  final_output.start
  call = engine.start
  input.start
  p call.wait.inspect
rescue Interrupt
  engine.finish
end
