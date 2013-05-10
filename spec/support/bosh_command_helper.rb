module Bosh::Spec
  module CommandHelper
    def run(cmd)
      Bundler.with_clean_env do
        lines = []
        IO.popen(cmd).each do |line|
          puts line.chomp
          lines << line.chomp
        end.close # force the process to close so that $? is set

        cmd_out = lines.join("\n")
        if $?.success?
          return cmd_out
        else
          raise "Failed: '#{cmd}' from #{Dir.pwd}, with exit status #{$?.to_i}\n\n #{cmd_out}"
        end
      end
    end

    def run_bosh(cmd, work_dir = nil)
      Dir.chdir(work_dir || BOSH_WORK_DIR) do
        run "bosh -v -n --config '#{BOSH_CONFIG}' -C #{BOSH_CACHE_DIR} #{cmd}"
      end
    end
  end
end
