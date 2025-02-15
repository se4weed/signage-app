# Upload dictionary.txt as a custom vocabulary
require 'aws-sdk-transcribeservice'
require 'aws-sdk-s3'
require 'logger'

S3_BUCKET = 'rubykaigi-custom-vocabs'
S3_PREFIX = 'training-out/vocab/'
VOCABULARY_NAME = ENV.fetch('TRANSCRIBE_VOCABULARY_NAME', 'rk_2025_words')

logger = Logger.new($stdout)
@transcribe = Aws::TranscribeService::Client.new(region: 'ap-northeast-1', logger:)
@s3 = Aws::S3::Client.new(region: 'ap-northeast-1', logger:)

tsv = File.read('dictionary.txt').each_line(chomp: true).map do |line|
  phrase, displayas = line.split(?\t)
  [phrase, '', '', displayas].join(?\t)
end.tap { _1.push(''); _1.unshift("Phrase\tSoundsLike\tIPA\tDisplayAs") }.join(?\n)

key =  "#{S3_PREFIX}#{VOCABULARY_NAME}.txt"
@s3.put_object(
  bucket: S3_BUCKET,
  key:,
  content_type: 'text/plain',
  body: tsv,
)

pp @transcribe.create_vocabulary(
  vocabulary_name: VOCABULARY_NAME,
  language_code: 'en-US',
  vocabulary_file_uri: "s3://#{S3_BUCKET}/#{key}",
  tags: [
    {
      key: "Project",
      value: "caption-training",
    },
  ]
)
