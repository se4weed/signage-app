# Transcribe source mp4 files for next steps
require 'aws-sdk-s3'
require 'logger'
require 'fileutils'

S3_BUCKET = 'rubykaigi-custom-vocabs'
S3_PREFIX = 'training/'

source = ARGV[0] or abort "Usage: #$0 source_name"
logger = Logger.new($stdout)
@s3 = Aws::S3::Client.new(region: 'ap-northeast-1', logger:)

transcript_key =  "#{S3_PREFIX}rec-transcript/#{source}.json"
FileUtils.mkdir_p File.join('tmp', 'rec-transcript')
transcript_content = File.open(File.join('tmp', 'rec-transcript', "#{source}.json"), 'w+') do |io|
  @s3.get_object(bucket: S3_BUCKET, key: transcript_key, response_target: io)
  io.flush
  io.rewind
  JSON.parse(io.read)
end

FileUtils.mkdir_p File.join('tmp', 'rec-transcript')
File.write File.join('tmp', 'rec-transcript', "#{source}.txt"), "#{transcript_content.fetch('results').fetch('transcripts').map { _1.fetch('transcript') }.join("\n").gsub(/\.\s+/, ".\n\n").chomp}\n"
