require 'common/thread_pool'

module Bosh::Dev
  class TestRunner
    def ruby(parallel: false)
      error_happened = false
      log_dir = Dir.mktmpdir
      puts "Logging spec results in #{log_dir}"
      test_output_lock = Mutex.new

      max_threads = ENV.fetch('BOSH_MAX_THREADS', 10).to_i
      null_logger = Logging::Logger.new('Ignored')
      Bosh::ThreadPool.new(max_threads: max_threads, logger: null_logger).wrap do |pool|
        unit_builds.each do |build|
          pool.process do
            test_return = unit_exec(build, log_file: "#{log_dir}/#{build}.log", parallel: parallel)
            if test_return[:error] == true
              error_happened = true
            end
            test_output_lock.synchronize {
              puts test_return[:lines]
            }
          end
        end

        pool.wait
      end

      if error_happened
        raise "Failed while running tests. See output above for more information."
      end
    end

    def unit_cmd(log_file = nil)
      "".tap do |cmd|
        cmd << 'rspec --tty --backtrace -c -f p spec'
        cmd << " > #{log_file} 2>&1" if log_file
      end
    end

    def unit_parallel(build_name, log_file = nil)
      cmd = "parallel_test --test-options '--no-fail-fast' --type rspec --runtime-log /tmp/bosh_#{build_name}_parallel_runtime_rspec.log spec"
      cmd << " > #{log_file} 2>&1" if log_file
      cmd
    end

    def unit_builds
      @unit_builds ||= begin
                         builds = Dir['*'].select do |f|
                           File.directory?(f) && File.exist?("#{f}/spec")
                         end.sort
                         builds -= %w(bat)
                       end
    end

    private

    def unit_exec(build, log_file: nil, parallel: false)
      lines = []
      command = parallel ? unit_parallel(build, log_file) : unit_cmd(log_file)

      # inject command name so coverage results for each component don't clobber others
      if Kernel.system({'BOSH_BUILD_NAME' => build}, "cd #{build} && #{command}")
        lines.append "----- BEGIN #{build}"
        lines.append "            #{command}"
        lines.append(File.read(log_file)) if log_file && File.exist?(log_file)
        lines.append "----- END   #{build}\n\n"

        {:lines => lines, :error => false}
      else
        lines.append "----- BEGIN #{build}"
        lines.append "            #{command}"
        error_message = "#{build} failed to build or run unit tests"
        error_message += ": #{File.read(log_file)}" if log_file && File.exist?(log_file)
        lines.append "            #{error_message}\n"
        lines.append "----- END   #{build}\n\n"

        {:lines => lines, :error => true}
      end
    end
  end
end
