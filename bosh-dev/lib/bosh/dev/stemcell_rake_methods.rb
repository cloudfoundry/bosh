require 'fileutils'

require 'bosh/dev/shell'
require 'bosh/stemcell/infrastructure'

module Bosh::Dev
  class StemcellRakeMethods
    def initialize(environment = ENV.to_hash, shell = Shell.new)
      @environment = environment
      @shell = shell
    end

    def bosh_micro_options(infrastructure, tarball)
      {
        bosh_micro_enabled: 'yes',
        bosh_micro_package_compiler_path: File.join(source_root, 'package_compiler'),
        bosh_micro_manifest_yml_path: File.join(source_root, "release/micro/#{infrastructure}.yml"),
        bosh_micro_release_tgz_path: tarball,
      }
    end

    def default_options(args)
      infrastructure = args.fetch(:infrastructure) do
        abort 'Please specify target infrastructure (vsphere, aws, openstack)'
      end

      stemcell_tgz = args.fetch(:stemcell_tgz) do
        abort 'Please specify stemcell tarball output path as stemcell_tgz'
      end

      stemcell_version = args.fetch(:stemcell_version) do
        abort 'Please specify stemcell_version'
      end

      options = {
        'system_parameters_infrastructure' => infrastructure,
        'stemcell_name' => environment.fetch('STEMCELL_NAME', 'bosh-stemcell'),
        'stemcell_infrastructure' => infrastructure,
        'stemcell_tgz' => stemcell_tgz,
        'stemcell_version' => stemcell_version,
        'stemcell_hypervisor' => hypervisor_for(infrastructure),
        'bosh_protocol_version' => Bosh::Agent::BOSH_PROTOCOL,
        'UBUNTU_ISO' => environment['UBUNTU_ISO'],
        'UBUNTU_MIRROR' => environment['UBUNTU_MIRROR'],
        'TW_LOCAL_PASSPHRASE' => environment['TW_LOCAL_PASSPHRASE'],
        'TW_SITE_PASSPHRASE' => environment['TW_SITE_PASSPHRASE'],
        'ruby_bin' => environment['RUBY_BIN'] || File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']),
        'bosh_release_src_dir' => File.join(source_root, 'release/src/bosh'),
        'bosh_agent_src_dir' => File.join(source_root, 'bosh_agent'),
      }

      options = check_for_ovftool(options) if infrastructure == 'vsphere'

      options.merge('image_create_disk_size' => default_disk_size_for(infrastructure, args))
    end

    def build(spec, options)
      root = get_working_dir
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

    attr_reader :environment, :shell

    def source_root
      File.expand_path('../../../../..', __FILE__)
    end

    def get_working_dir
      environment['BUILD_PATH'] || "/var/tmp/bosh/bosh_agent-#{Bosh::Agent::VERSION}-#{Process.pid}"
    end

    def env
      keep = %w(HTTP_PROXY NO_PROXY)

      format_env(environment.select { |k| keep.include?(k.upcase) })
    end

    # Format a hash as an env command.
    def format_env(h)
      'env ' + h.map { |k, v| "#{k}='#{v}'" }.join(' ')
    end

    def check_for_ovftool(options)
      ovftool_path = environment['OVFTOOL']
      options.merge('image_vsphere_ovf_ovftool_path' => ovftool_path)
    end

    def default_disk_size_for(infrastructure, args)
      return args[:disk_size] if args[:disk_size]

      Bosh::Stemcell::Infrastructure.for(infrastructure).default_disk_size
    end

    def hypervisor_for(infrastructure)
      return environment['STEMCELL_HYPERVISOR'] if environment['STEMCELL_HYPERVISOR']

      begin
        Bosh::Stemcell::Infrastructure.for(infrastructure).hypervisor
      rescue ArgumentError
        raise "Unknown infrastructure: #{infrastructure}"
      end
    end
  end
end
