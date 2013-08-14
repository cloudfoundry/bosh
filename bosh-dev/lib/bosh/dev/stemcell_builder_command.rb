require 'fileutils'

require 'bosh_agent/version'
require 'bosh/dev/shell'

module Bosh::Dev
  class StemcellBuilderCommand
    def initialize(environment, spec, options)
      @shell = Shell.new
      @environment = environment
      @spec = spec
      @options = options
    end

    def build
      FileUtils.mkdir_p root
      puts "MADE ROOT: #{root}"
      puts "PWD: #{Dir.pwd}"

      build_path = File.join(root, 'build')
      FileUtils.rm_rf build_path if Dir.exists?(build_path)
      FileUtils.mkdir_p build_path
      stemcell_build_dir = File.join(source_root, 'stemcell_builder')
      FileUtils.cp_r Dir.glob("#{stemcell_build_dir}/*"), build_path, preserve: true

      work_path = environment['WORK_PATH'] || File.join(root, 'work')
      FileUtils.mkdir_p work_path

      # Apply options
      settings_dir = File.join(build_path, 'etc')
      settings_path = File.join(settings_dir, 'settings.bash')
      File.open(settings_path, 'a') do |f|
        f.printf("\n# %s\n\n", '=' * 20)
        options.each do |k, v|
          f.print "#{k}=#{v}\n"
        end
      end

      builder_path = File.join(build_path, 'bin', 'build_from_spec.sh')
      spec_path = File.join(build_path, 'spec', "#{spec}.spec")

      puts "Building in #{work_path}..."
      cmd = "sudo #{env} #{builder_path} #{work_path} #{spec_path} #{settings_path}"

      shell.run cmd
    end

    private

    attr_reader :shell, :spec, :options, :environment

    def env
      keep = %w(HTTP_PROXY NO_PROXY)

      format_env(environment.select { |k| keep.include?(k.upcase) })
    end

    def format_env(env)
      'env ' + env.map { |k, v| "#{k}='#{v}'" }.join(' ')
    end

    def source_root
      File.expand_path('../../../../..', __FILE__)
    end

    def root
      @root ||= environment['BUILD_PATH'] || "/var/tmp/bosh/bosh_agent-#{Bosh::Agent::VERSION}-#{Process.pid}"
    end
  end
end
