module Bosh::Spec
  module AwsBootstrapCommandHelper
    def run(cmd)
      output = ''
      IO.popen(cmd).each do |line|
        puts line.chomp
        output << line
      end.close # force the process to close so that $? is set

      if $?.success?
        output
      else
        raise "Failed: '#{cmd}' from #{Dir.pwd}, with exit status #{$?.exitstatus}\n\n#{output}"
      end
    end

    def run_bosh(cmd, work_dir = nil)
      Dir.chdir(work_dir || ClientSandbox.bosh_work_dir) do
        run "bosh -v -n --config '#{ClientSandbox.bosh_config}' #{cmd}"
      end
    end
  end
end
