require 'bosh/core/shell'

module Bosh::Stemcell
  class StageRunner

    REQUIRED_UID=1000

    def initialize(options)
      @build_path = options.fetch(:build_path)
      @command_env = options.fetch(:command_env)
      @settings_file = options.fetch(:settings_file)
      @work_path = options.fetch(:work_path)
    end

    def check_correct_uid
      if Process.euid != REQUIRED_UID
        raise "You must build stemcells as a user with UID #{REQUIRED_UID}. Your effective UID now is #{Process.euid}."
      end
    end

    def configure_and_apply(stages, resume_from_stage = nil)
      check_correct_uid()
      stages = resume_from(stages, resume_from_stage)
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

        begin
          stage_apply_script = File.join(build_path, 'stages', stage.to_s, 'apply.sh')

          run_sudo_with_command_env("#{stage_apply_script} #{work_path}")

        rescue => _
          puts "=== You can resume_from the '#{stage}' stage by using resume_from=#{stage} ==="
          raise
        end

      end
    end

    private

    attr_reader :stages, :build_path, :command_env, :settings_file, :work_path

    def resume_from(all_stages, resume_from_stage)
      if resume_from_stage != NIL
        stage_index = all_stages.index(resume_from_stage.to_sym)
        if stage_index == NIL
          raise "Can't find stage '#{resume_from_stage}' to resume from. Aborting."
        end
        all_stages.drop(stage_index)
      else
        all_stages
      end
    end

    def run_sudo_with_command_env(command)
      shell = Bosh::Core::Shell.new

      shell.run("sudo #{command_env} #{command} 2>&1", output_command: true)
    end
  end
end
