require 'fileutils'
require 'thread'
FileUtils.mkdir_p 'tmp/log'

sources = [
  *Dir["./tmp/rec/*.mp4"].map { File.basename(_1, ".mp4") },
  *Dir["./tmp/rec-transcript/*.txt"].map { File.basename(_1, ".txt") },
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
  next unless File.exist?(File.join('tmp', 'rec', "#{source}.mp4"))
  pid = File.open(File.join('tmp', 'log', "#{source}.1.log"), 'w') do |io|
    spawn('ruby', 'dictionary_1_source.rb', '--skip', source, out: io, err: [:child, :out])
  end
  [pid, "1-source|#{source}"]
end.to_h

waitall(step1)

step2 = {}
queue = Queue.new
#queue.push(true)
queue.push(true)

th = Thread.new do
  waitall(step2) do
    queue.push(true)
  end
end
th.abort_on_exception=true

sources.each do |source|
  queue.pop
  pid = File.open(File.join('tmp', 'log', "#{source}.2.log"), 'w') do |io|
    spawn('ruby', 'dictionary_2_refine.rb', '--skip', source, out: io, err: [:child, :out])
  end
  @lock.synchronize do
    step2[pid] = "2-refine|#{source}"
  end
end
#sources.each do |source|
#  queue.pop
#  pid = File.open(File.join('tmp', 'log', "#{source}.2b.log"), 'w') do |io|
#    spawn('ruby', 'dictionary_2_refine.rb', '--dic', '--skip', source, out: io, err: [:child, :out])
#  end
#  @lock.synchronize do
#    step2[pid] = "2-refine-dic|#{source}"
#  end
#end
