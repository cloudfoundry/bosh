require 'fileutils'

require 'bosh/dev/shell'

module Bosh::Dev
  class StemcellBuilderCommand
    def initialize(spec, build_path, work_path, settings)
      @shell = Shell.new
      @environment = ENV.to_hash
      @spec = spec
      @root = build_path
      @work_path = work_path
      @settings = settings
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

      FileUtils.mkdir_p work_path

      # Apply settings
      settings_dir = File.join(build_path, 'etc')
      settings_path = File.join(settings_dir, 'settings.bash')
      File.open(settings_path, 'a') do |f|
        f.printf("\n# %s\n\n", '=' * 20)
        settings.each do |k, v|
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

    attr_reader :shell,
                :spec,
                :settings,
                :environment,
                :root,
                :work_path

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
  end
end
