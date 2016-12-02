trap 'QUIT' do
  threads = Thread.list
  PID = Process.pid
  STDERR.puts "#{PID}: Dumping stack traces for #{threads.size} threads:"
  threads.each do |thread|
    STDERR.puts "#{PID}: Thread-#{thread.object_id.to_s(36)}"
    STDERR.puts thread.backtrace.join("\n#{PID}:  ")
  end
end

puts "Installed SIGQUIT stack trace handler on PID #{Process.pid}"
