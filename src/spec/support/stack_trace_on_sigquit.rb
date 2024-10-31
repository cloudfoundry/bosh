trap 'QUIT' do
  current_pid = Process.pid
  current_threads = Thread.list
  STDERR.puts "PID: #{current_pid}: Dumping stack traces for #{current_threads.size} threads:"
  current_threads.each do |thread|
    STDERR.puts "#{current_pid}: Thread-#{thread.object_id.to_s(36)}"
    STDERR.puts thread.backtrace.join("\n#{current_pid}:  ")
  end
end

puts "Installed SIGQUIT stack trace handler on PID #{Process.pid}"
