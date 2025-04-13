# Transcribe source mp4 files for next steps
require 'aws-sdk-transcribeservice'
require 'aws-sdk-s3'
require 'logger'
require 'fileutils'

is_try = ARGV.delete('--try')
S3_BUCKET = 'rubykaigi-custom-vocabs'
S3_PREFIX = is_try ? 'training-try/' : 'training/'
VOCABULARY_NAME = ENV.fetch('TRANSCRIBE_VOCABULARY_NAME', 'rk_2025_words')
LANGUAGE_MODEL_NAME = ENV.fetch('TRANSCRIBE_LANGUAGE_MODEL_NAME', 'rk2025w')

is_skip = ARGV.delete('--skip')
source = ARGV[0] or abort "Usage: #$0 source_name"
tmpdir = is_try ? File.join('tmp', 'try') : 'tmp'
logger = Logger.new($stdout)

@transcribe = Aws::TranscribeService::Client.new(region: 'ap-northeast-1', logger:)
@s3 = Aws::S3::Client.new(region: 'ap-northeast-1', logger:)

if is_skip && File.exist?(File.join(tmpdir, 'rec-transcript', "#{source}.json"))
  puts "skip"
  exit 0
end

FileUtils.mkdir_p File.join(tmpdir, 'rec-audio')
FileUtils.mkdir_p File.join(tmpdir, 'rec-transcript')

mp4 = File.join(tmpdir, 'rec', "#{source}.mp4")
audio = File.join(tmpdir, 'rec-audio', "#{source}.m4a")
audio_key = "#{S3_PREFIX}rec/#{source}.m4a"
unless File.exist?(audio)
  system("ffmpeg", "-y", "-i", mp4, "-c:a", "copy", "-map", "0:a:0", audio, exception: true)
end
File.open(audio, "rb") do |io|
  @s3.put_object(bucket: S3_BUCKET, key: audio_key, content_type: "audio/mp4", body: io)
end

transcription_job_name =  "#{source}--#{Time.now.to_i}"
transcript_key =  "#{S3_PREFIX}rec-transcript/#{source}.json"
job = @transcribe.start_transcription_job(
  transcription_job_name:,
  media_format: "m4a",
  media: {
    media_file_uri: "s3://#{S3_BUCKET}/#{audio_key}",
  },
  output_bucket_name: S3_BUCKET,
  output_key: transcript_key,

  language_code: 'en-US',
  settings: {
    vocabulary_name: VOCABULARY_NAME,
  },
  model_settings: {
    language_model_name: LANGUAGE_MODEL_NAME,
  },
  #identify_language: true,
  #language_options: %w(en-AB en-AU en-GB en-IE en-IN en-US en-WL),
  #language_id_settings: {
  #  "en-US" => {
  #    vocabulary_name: VOCABULARY_NAME,
  #    language_model_name: LANGUAGE_MODEL_NAME,
  #  },
  #},

  subtitles: {
    formats: ["vtt"], # accepts vtt, srt
    output_start_index: 1,
  },
  tags: [
    {
      key: "Project",
      value: "caption-training",
    },
  ],
).transcription_job

loop do
  job = @transcribe.get_transcription_job(transcription_job_name:).transcription_job
  break if job.transcription_job_status == 'FAILED' || job.transcription_job_status == 'COMPLETED'
  sleep 3
end

transcript_content = File.open(File.join(tmpdir, 'rec-transcript', "#{source}.json"), 'w+') do |io|
  @s3.get_object(bucket: S3_BUCKET, key: transcript_key, response_target: io)
  io.flush
  io.rewind
  JSON.parse(io.read)
end

File.write File.join(tmpdir, 'rec-transcript', "#{source}.txt"), "#{transcript_content.fetch('results').fetch('transcripts').map { _1.fetch('transcript') }.join("\n").gsub(/\.\s+/, ".\n\n").chomp}\n"
