require 'rbconfig'

require 'bosh_agent/version'
require 'bosh/stemcell/infrastructure'

module Bosh::Dev
  class StemcellBuilderOptions
    def initialize(options)
      @environment = options.fetch(:environment)
      @args = options.fetch(:args)
    end

    def default
      infrastructure = Bosh::Stemcell::Infrastructure.for(args.fetch(:infrastructure))
      stemcell_tgz = args.fetch(:stemcell_tgz)
      stemcell_version = args.fetch(:stemcell_version)

      options = {
        'system_parameters_infrastructure' => infrastructure.name,
        'stemcell_name' => 'bosh-stemcell',
        'stemcell_infrastructure' => infrastructure.name,
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
        'bosh_micro_enabled' => 'yes',
        'bosh_micro_package_compiler_path' => File.join(source_root, 'package_compiler'),
        'bosh_micro_manifest_yml_path' => File.join(source_root, "release/micro/#{args[:infrastructure]}.yml"),
        'bosh_micro_release_tgz_path' => args.fetch(:tarball)
      }

      options = check_for_ovftool(options) if infrastructure.name == 'vsphere'

      options.merge('image_create_disk_size' => default_disk_size_for(infrastructure, args))
    end

    private

    attr_reader :environment, :args

    def hypervisor_for(infrastructure)
      return environment['STEMCELL_HYPERVISOR'] if environment['STEMCELL_HYPERVISOR']

      infrastructure.hypervisor
    end

    def check_for_ovftool(options)
      ovftool_path = environment['OVFTOOL']
      options.merge('image_vsphere_ovf_ovftool_path' => ovftool_path)
    end

    def default_disk_size_for(infrastructure, args)
      return args[:disk_size] if args[:disk_size]

      infrastructure.default_disk_size
    end

    def source_root
      File.expand_path('../../../../..', __FILE__)
    end
  end
end
