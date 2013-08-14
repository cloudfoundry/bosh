require 'rbconfig'

require 'bosh_agent/version'
require 'bosh/stemcell/infrastructure'

module Bosh::Dev
  class StemcellBuilderOptions
    def initialize(options)
      @environment = options.fetch(:environment)
      @args = options.fetch(:args)
    end

    def basic
      infrastructure = args.fetch(:infrastructure)
      stemcell_tgz = args.fetch(:stemcell_tgz)
      stemcell_version = args.fetch(:stemcell_version)

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

    private

    attr_reader :environment, :args

    def hypervisor_for(infrastructure)
      return environment['STEMCELL_HYPERVISOR'] if environment['STEMCELL_HYPERVISOR']

      begin
        Bosh::Stemcell::Infrastructure.for(infrastructure).hypervisor
      rescue ArgumentError
        raise "Unknown infrastructure: #{infrastructure}"
      end
    end

    def check_for_ovftool(options)
      ovftool_path = environment['OVFTOOL']
      options.merge('image_vsphere_ovf_ovftool_path' => ovftool_path)
    end

    def default_disk_size_for(infrastructure, args)
      return args[:disk_size] if args[:disk_size]

      Bosh::Stemcell::Infrastructure.for(infrastructure).default_disk_size
    end

    def source_root
      File.expand_path('../../../../..', __FILE__)
    end
  end
end
