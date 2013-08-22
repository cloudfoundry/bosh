require 'fileutils'

require 'bosh/core/shell'
require 'bosh/dev/stemcell_environment'
require 'bosh/dev/stemcell_builder_options'

module Bosh::Dev
  class StemcellBuilderCommand
    def initialize(build, infrastructure, operating_system)
      @shell = Bosh::Core::Shell.new
      @environment = ENV.to_hash
      @stemcell_environment = StemcellEnvironment.new(infrastructure_name: infrastructure.name)
      bosh_release_tarball_path = build.download_release
      @stemcell_builder_options = StemcellBuilderOptions.new(args: { tarball: bosh_release_tarball_path,
                                                                     stemcell_version: build.number,
                                                                     infrastructure: infrastructure })
    end

    def build
      stemcell_environment.sanitize

      prepare_build_root

      prepare_build_path

      copy_stemcell_builder_to_build_path

      prepare_work_path

      persist_settings_for_bash

      shell.run "sudo #{env} #{build_from_spec_shell_file} #{work_path} #{stemcell_spec_file_path} #{settings_file_path}"

      File.join(work_path, 'work', settings['stemcell_tgz'])
    end

    private

    attr_reader :shell,
                :environment,
                :stemcell_environment,
                :stemcell_builder_options

    def spec_name
      stemcell_builder_options.spec_name
    end

    def settings
      stemcell_builder_options.default
    end

    def build_root
      stemcell_environment.build_path
    end

    def work_path
      stemcell_environment.work_path
    end

    def prepare_build_root
      FileUtils.mkdir_p build_root
      puts "MADE ROOT: #{build_root}"
      puts "PWD: #{Dir.pwd}"
    end

    def build_path
      File.join(build_root, 'build')
    end

    def prepare_build_path
      FileUtils.rm_rf build_path if Dir.exists?(build_path)
      FileUtils.mkdir_p build_path
    end

    def stemcell_builder_source_dir
      File.join(File.expand_path('../../../../..', __FILE__), 'stemcell_builder')
    end

    def copy_stemcell_builder_to_build_path
      FileUtils.cp_r(Dir.glob("#{stemcell_builder_source_dir}/*"), build_path, preserve: true)
    end

    def prepare_work_path
      puts "Building in #{work_path}..."
      FileUtils.mkdir_p work_path
    end

    def settings_file_path
      File.join(build_path, 'etc', 'settings.bash')
    end

    def persist_settings_for_bash
      File.open(settings_file_path, 'a') do |f|
        f.printf("\n# %s\n\n", '=' * 20)
        settings.each do |k, v|
          f.print "#{k}=#{v}\n"
        end
      end
    end

    def build_from_spec_shell_file
      File.join(build_path, 'bin', 'build_from_spec.sh')
    end

    def stemcell_spec_file_path
      File.join(build_path, 'spec', "#{spec_name}.spec")
    end

    def env
      "env #{hash_as_bash_env(proxy_settings_from_environment)}"
    end

    def proxy_settings_from_environment
      keep = %w(HTTP_PROXY NO_PROXY)

      environment.select { |k| keep.include?(k.upcase) }
    end

    def hash_as_bash_env(env)
      env.map { |k, v| "#{k}='#{v}'" }.join(' ')
    end
  end
end
