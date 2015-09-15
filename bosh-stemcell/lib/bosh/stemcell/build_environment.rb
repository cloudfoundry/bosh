require 'bosh/core/shell'
require 'bosh/stemcell/builder_options'
require 'bosh/stemcell/stemcell'
require 'forwardable'

module Bosh::Stemcell
  class BuildEnvironment
    extend Forwardable

    STEMCELL_BUILDER_SOURCE_DIR = File.join(File.expand_path('../../../../..', __FILE__), 'stemcell_builder')
    STEMCELL_SPECS_DIR = File.expand_path('../../..', File.dirname(__FILE__))

    def initialize(env, definition, version, release_tarball_path, os_image_tarball_path)
      @environment = env
      @definition = definition
      @os_image_tarball_path = os_image_tarball_path
      @version = version
      @stemcell_builder_options = BuilderOptions.new(
        env: env,
        definition: definition,
        version: version,
        release_tarball: release_tarball_path,
        os_image_tarball: os_image_tarball_path,
      )
      @shell = Bosh::Core::Shell.new
    end

    attr_reader :version

    def prepare_build
      if (ENV['resume_from'] == NIL)
        sanitize
        prepare_build_path
      end
      copy_stemcell_builder_to_build_path
      prepare_work_root
      prepare_stemcell_path
      persist_settings_for_bash
    end

    def os_image_rspec_command
      [
        "cd #{STEMCELL_SPECS_DIR};",
        "OS_IMAGE=#{os_image_tarball_path}",
        'bundle exec rspec -fd',
        "spec/os_image/#{operating_system_spec_name}_spec.rb",
      ].join(' ')
    end

    def stemcell_rspec_command
      [
        "cd #{STEMCELL_SPECS_DIR};",
        "STEMCELL_IMAGE=#{image_file_path}",
        "STEMCELL_WORKDIR=#{work_path}",
        "bundle exec rspec -fd#{exclude_exclusions}",
        "spec/os_image/#{operating_system_spec_name}_spec.rb",
        "spec/stemcells/#{operating_system_spec_name}_spec.rb",
        "spec/stemcells/#{agent.name}_agent_spec.rb",
        "spec/stemcells/#{infrastructure.name}_spec.rb",
      ].join(' ')
    end

    def build_path
      File.join(build_root, 'build')
    end

    def stemcell_files
      definition.disk_formats.map do |disk_format|
        stemcell_filename = Stemcell.new(@definition, 'bosh-stemcell', @version, disk_format)
        File.join(work_path, stemcell_filename.name)
      end
    end

    def chroot_dir
      File.join(work_path, 'chroot')
    end

    def settings_path
      File.join(build_path, 'etc', 'settings.bash')
    end

    def work_path
      File.join(work_root, 'work')
    end

    def stemcell_tarball_path
      work_path
    end

    def stemcell_disk_size
      stemcell_builder_options.image_create_disk_size
    end

    def command_env
      "env #{hash_as_bash_env(proxy_settings_from_environment)}"
    end

    private

    def_delegators(
      :@definition,
      :infrastructure,
      :operating_system,
      :agent,
    )

    attr_reader(
      :shell,
      :environment,
      :definition,
      :stemcell_builder_options,
      :os_image_tarball_path,
    )

    def sanitize
      FileUtils.rm(Dir.glob('*.tgz'))

      shell.run("sudo umount #{File.join(work_path, 'mnt/tmp/grub', settings['stemcell_image_name'])} 2> /dev/null",
                { ignore_failures: true })

      shell.run("sudo umount #{image_mount_point} 2> /dev/null", { ignore_failures: true })

      shell.run("sudo rm -rf #{base_directory}", { ignore_failures: true })
    end

    def operating_system_spec_name
      "#{operating_system.name}_#{operating_system.version}"
    end

    def prepare_build_path
      FileUtils.rm_rf(build_path, verbose: true) if File.exist?(build_path)
      FileUtils.mkdir_p(build_path, verbose: true)
    end

    def prepare_stemcell_path
      FileUtils.mkdir_p(File.join(work_path, 'stemcell'))
    end

    def copy_stemcell_builder_to_build_path
      FileUtils.cp_r(Dir.glob("#{STEMCELL_BUILDER_SOURCE_DIR}/*"), build_path, preserve: true, verbose: true)
    end

    def prepare_work_root
      FileUtils.mkdir_p(work_root, verbose: true)
    end

    def persist_settings_for_bash
      File.open(settings_path, 'a') do |f|
        f.printf("\n# %s\n\n", '=' * 20)
        settings.each do |k, v|
          f.print "#{k}=#{v}\n"
        end
      end
    end

    def exclude_exclusions
      case infrastructure.name
      when 'vsphere'
        ' --tag ~exclude_on_vsphere'
      when 'vcloud'
        ' --tag ~exclude_on_vcloud'
      when 'warden'
        ' --tag ~exclude_on_warden'
      when 'aws'
        ' --tag ~exclude_on_aws'
      when 'openstack'
        ' --tag ~exclude_on_openstack'
      else
        ''
      end
    end

    def image_file_path
      File.join(work_path, settings['stemcell_image_name'])
    end

    def image_mount_point
      File.join(work_path, 'mnt')
    end

    def settings
      stemcell_builder_options.default
    end

    def base_directory
      File.join('/mnt', 'stemcells', infrastructure.name, infrastructure.hypervisor, operating_system.name)
    end

    def build_root
      File.join(base_directory, 'build')
    end

    def work_root
      File.join(base_directory, 'work')
    end

    def proxy_settings_from_environment
      keep = %w(HTTP_PROXY HTTPS_PROXY NO_PROXY)

      environment.select { |k| keep.include?(k.upcase) }
    end

    def hash_as_bash_env(env)
      env.map { |k, v| "#{k}='#{v}'" }.join(' ')
    end
  end
end
