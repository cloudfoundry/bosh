require 'fileutils'

require 'bosh/core/shell'
require 'bosh/stemcell/environment'
require 'bosh/stemcell/builder_options'
require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Stemcell
  class BuilderCommand
    def initialize(options)
      infrastructure = Infrastructure.for(options.fetch(:infrastructure_name))
      operating_system = OperatingSystem.for(options.fetch(:operating_system_name))

      @stemcell_environment = Environment.new(infrastructure_name: infrastructure.name)
      @stemcell_builder_options = BuilderOptions.new(tarball: options.fetch(:release_tarball_path),
                                                     stemcell_version: options.fetch(:version),
                                                     infrastructure: infrastructure,
                                                     operating_system: operating_system)
      @environment = ENV.to_hash
      @shell = Bosh::Core::Shell.new
    end

    def build
      stemcell_environment.sanitize

      prepare_build_root

      prepare_build_path

      copy_stemcell_builder_to_build_path

      prepare_work_path

      persist_settings_for_bash

      shell.run "sudo #{command_env} #{build_from_spec_path} #{work_path} #{stemcell_spec_path} #{settings_path}"

      stemcell_file
    end

    private

    attr_reader :shell,
                :environment,
                :stemcell_environment,
                :stemcell_builder_options

    def spec_name
      "#{stemcell_builder_options.spec_name}.spec"
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
      FileUtils.mkdir_p(build_root, verbose: true)
    end

    def build_path
      File.join(build_root, 'build')
    end

    def prepare_build_path
      FileUtils.rm_rf(build_path, verbose: true) if Dir.exists?(build_path)
      FileUtils.mkdir_p(build_path, verbose: true)
    end

    def stemcell_builder_source_dir
      File.join(File.expand_path('../../../../..', __FILE__), 'stemcell_builder')
    end

    def copy_stemcell_builder_to_build_path
      FileUtils.cp_r(Dir.glob("#{stemcell_builder_source_dir}/*"), build_path, preserve: true, verbose: true)
    end

    def prepare_work_path
      FileUtils.mkdir_p(work_path, verbose: true)
    end

    def settings_path
      File.join(build_path, 'etc', 'settings.bash')
    end

    def persist_settings_for_bash
      File.open(settings_path, 'a') do |f|
        f.printf("\n# %s\n\n", '=' * 20)
        settings.each do |k, v|
          f.print "#{k}=#{v}\n"
        end
      end
    end

    def build_from_spec_path
      File.join(build_path, 'bin', 'build_from_spec.sh')
    end

    def stemcell_spec_path
      File.join(build_path, 'spec', spec_name)
    end

    def command_env
      "env #{hash_as_bash_env(proxy_settings_from_environment)}"
    end

    def stemcell_file
      File.join(work_path, 'work', settings['stemcell_tgz'])
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
