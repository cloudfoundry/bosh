require 'bosh/core/shell'

module Bosh::Stemcell
  class StageRunner
    def initialize(options)
      @build_path = options.fetch(:build_path)
      @command_env = options.fetch(:command_env)
      @settings_file = options.fetch(:settings_file)
      @work_path = options.fetch(:work_path)
    end

    def configure_and_apply(stages)
      configure(stages)
      apply(stages)
    end

    def configure(stages)
      stages.each do |stage|
        stage_config_script = File.join(build_path, 'stages', stage.to_s, 'config.sh')

        puts "=== Configuring '#{stage}' stage ==="
        puts "== Started #{Time.now.strftime('%a %b %e %H:%M:%S %Z %Y')} =="
        if File.exists?(stage_config_script) && File.executable?(stage_config_script)
          run_sudo_with_command_env("#{stage_config_script} #{settings_file}")
        end
      end
    end

    def apply(stages)
      stages.each do |stage|
        FileUtils.mkdir_p(work_path)

        puts "=== Applying '#{stage}' stage ==="
        puts "== Started #{Time.now.strftime('%a %b %e %H:%M:%S %Z %Y')} =="

        stage_apply_script = File.join(build_path, 'stages', stage.to_s, 'apply.sh')

        run_sudo_with_command_env("#{stage_apply_script} #{work_path}")
      end
    end

    private

    attr_reader :stages, :build_path, :command_env, :settings_file, :work_path

    def run_sudo_with_command_env(command)
      shell = Bosh::Core::Shell.new

      shell.run("sudo #{command_env} #{command} 2>&1", output_command: true)
    end
  end
end
