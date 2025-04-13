require 'fileutils'
require 'thread'
FileUtils.mkdir_p 'tmp/log'

sources = [
  *Dir["./tmp/try/rec/*.mp4"].map { File.basename(_1, ".mp4") },
  *Dir["./tmp/try/rec-audio/*.m4a"].map { File.basename(_1, ".m4a") },
].sort.uniq

@lock = Mutex.new
def waitall(jobs, &block)
  failed = false
  loop do
    if block
    else
      break if jobs.empty?
    end
    pid,status = Process.waitpid2
    job = @lock.synchronize { jobs.delete(pid) }
    block&.call(job)
    unless job
      warn status.inspect
      next
    end
    if status.success?
      warn "#{job} > [ ok  ]"
    else
      warn "#{job} ! [ err ] #{status.inspect}"
      failed = true
    end
  end
  exit 1 if failed
end

step1 = sources.filter_map do |source|
  pid = File.open(File.join('tmp/try', 'log', "#{source}.1.log"), 'w') do |io|
    spawn('ruby', 'dictionary_1_source.rb', '--try', '--skip', source, out: io, err: [:child, :out])
  end
  [pid, "1-source|#{source}"]
end.to_h

waitall(step1)
