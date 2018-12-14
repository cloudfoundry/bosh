require 'common/thread_pool'

module Bosh::Dev
  class TestRunner
    def ruby(parallel: false)
      log_dir = Dir.mktmpdir
      puts "Logging spec results in #{log_dir}"

      max_threads = ENV.fetch('BOSH_MAX_THREADS', 10).to_i
      null_logger = Logging::Logger.new('Ignored')
      Bosh::ThreadPool.new(max_threads: max_threads, logger: null_logger).wrap do |pool|
        unit_builds.each do |build|
          pool.process do
            unit_exec(build, log_file: "#{log_dir}/#{build}.log", parallel: parallel)
          end
        end

        pool.wait
      end
    end

    def unit_exec(build, log_file: nil, parallel: false)
      command = parallel ? unit_parallel(build, log_file) : unit_cmd(log_file)

      # inject command name so coverage results for each component don't clobber others
      if Kernel.system({'BOSH_BUILD_NAME' => build}, "cd #{build} && #{command}")
        puts "----- BEGIN #{build}"
        puts "            #{command}"
        print File.read(log_file) if log_file && File.exists?(log_file)
        puts "----- END   #{build}\n\n"
      else
        error_message = "#{build} failed to build unit tests"
        error_message += ": #{File.read(log_file)}" if log_file && File.exists?(log_file)
        raise error_message
      end
    end

    def unit_cmd(log_file = nil)
      "".tap do |cmd|
        cmd << 'rspec --tty --backtrace -c -f p spec'
        cmd << " > #{log_file} 2>&1" if log_file
      end
    end

    def unit_parallel(build_name, log_file = nil)
      cmd = "parallel_test --type rspec --runtime-log /tmp/bosh_#{build_name}_parallel_runtime_rspec.log spec"
      cmd << " > #{log_file} 2>&1" if log_file
      cmd
    end

    def unit_builds
      @unit_builds ||= begin
                         builds = Dir['*'].select do |f|
                           File.directory?(f) && File.exists?("#{f}/spec")
                         end.sort
                         builds -= %w(bat)
                       end
    end
  end
end
