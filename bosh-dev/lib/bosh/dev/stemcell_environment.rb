require 'fileutils'

require 'bosh/stemcell/infrastructure'

module Bosh::Dev
  class StemcellEnvironment
    def initialize(builder, env = ENV.to_hash)
      @builder = builder
      @env = env
    end

    def sanitize
      FileUtils.rm_rf('*.tgz')

      system("sudo umount #{File.join(builder.work_path, 'work/mnt/tmp/grub/root.img')} 2> /dev/null")
      system("sudo umount #{File.join(builder.work_path, 'work/mnt')} 2> /dev/null")

      mnt_type = `df -T '#{builder.directory}' | awk '/dev/{ print $2 }'`
      mnt_type = 'unknown' if mnt_type.strip.empty?

      if mnt_type != 'btrfs'
        system("sudo rm -rf #{builder.directory}")
      end
    end

    def default_options(args)
      infrastructure = args.fetch(:infrastructure) do
        STDERR.puts 'Please specify target infrastructure (vsphere, aws, openstack)'
        exit 1
      end

      options = {
        'system_parameters_infrastructure' => infrastructure,
        'stemcell_name' => env['STEMCELL_NAME'],
        'stemcell_infrastructure' => infrastructure,
        'stemcell_hypervisor' => hypervisor_for(infrastructure),
        'bosh_protocol_version' => Bosh::Agent::BOSH_PROTOCOL,
        'UBUNTU_ISO' => env['UBUNTU_ISO'],
        'UBUNTU_MIRROR' => env['UBUNTU_MIRROR'],
        'TW_LOCAL_PASSPHRASE' => env['TW_LOCAL_PASSPHRASE'],
        'TW_SITE_PASSPHRASE' => env['TW_SITE_PASSPHRASE'],
        'ruby_bin' => env['RUBY_BIN'] || File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']),
        'bosh_release_src_dir' => File.expand_path('../../../../../release/src/bosh', __FILE__),
        'bosh_agent_src_dir' => File.expand_path('../../../../../bosh_agent', __FILE__),
      }

      options = check_for_ovftool!(options) if infrastructure == 'vsphere'

      options.merge('image_create_disk_size' => default_disk_size_for(infrastructure, args))
    end

    private

    def check_for_ovftool!(options)
      ovftool_path = env.fetch('OVFTOOL') do
        raise 'Please set OVFTOOL to the path of `ovftool`.'
      end
      options.merge('image_vsphere_ovf_ovftool_path' => ovftool_path)
    end

    def default_disk_size_for(infrastructure, args)
      return args[:disk_size] if args[:disk_size]

      Bosh::Stemcell::Infrastructure.for(infrastructure).default_disk_size
    end

    def hypervisor_for(infrastructure)
      return env['STEMCELL_HYPERVISOR'] if env['STEMCELL_HYPERVISOR']

      begin
        Bosh::Stemcell::Infrastructure.for(infrastructure).hypervisor
      rescue ArgumentError
        raise "Unknown infrastructure: #{infrastructure}"
      end
    end

    attr_reader :builder, :env
  end
end
