require 'rbconfig'

require 'bosh_agent/version'
require 'bosh/stemcell/archive_filename'

module Bosh::Dev
  class StemcellBuilderOptions
    def initialize(options)
      args = options.fetch(:args)
      @environment = ENV.to_hash
      @infrastructure = args.fetch(:infrastructure)

      @stemcell_version = args.fetch(:stemcell_version)
      @image_create_disk_size = args.fetch(:disk_size, infrastructure.default_disk_size)
      @bosh_micro_release_tgz_path = args.fetch(:tarball)
    end

    def spec_name
      "stemcell-#{infrastructure.name}"
    end

    def default
      options = {
        'system_parameters_infrastructure' => infrastructure.name,
        'stemcell_name' => 'bosh-stemcell',
        'stemcell_infrastructure' => infrastructure.name,
        'stemcell_tgz' => archive_filename.to_s,
        'stemcell_version' => stemcell_version,
        'stemcell_hypervisor' => hypervisor_for(infrastructure),
        'bosh_protocol_version' => Bosh::Agent::BOSH_PROTOCOL,
        'UBUNTU_ISO' => environment['UBUNTU_ISO'],
        'UBUNTU_MIRROR' => environment['UBUNTU_MIRROR'],
        'TW_LOCAL_PASSPHRASE' => environment['TW_LOCAL_PASSPHRASE'],
        'TW_SITE_PASSPHRASE' => environment['TW_SITE_PASSPHRASE'],
        'ruby_bin' => ruby_bin,
        'bosh_release_src_dir' => File.join(source_root, 'release/src/bosh'),
        'bosh_agent_src_dir' => File.join(source_root, 'bosh_agent'),
        'bosh_micro_enabled' => 'yes',
        'bosh_micro_package_compiler_path' => File.join(source_root, 'package_compiler'),
        'bosh_micro_manifest_yml_path' => File.join(source_root, 'release', 'micro', "#{infrastructure.name}.yml"),
        'bosh_micro_release_tgz_path' => bosh_micro_release_tgz_path,
        'image_create_disk_size' => image_create_disk_size
      }

      options.merge!('image_vsphere_ovf_ovftool_path' => environment['OVFTOOL']) if infrastructure.name == 'vsphere'

      options
    end

    private

    attr_reader :environment, :infrastructure, :stemcell_version, :image_create_disk_size, :bosh_micro_release_tgz_path

    def archive_filename
      Bosh::Stemcell::ArchiveFilename.new(stemcell_version, infrastructure, 'bosh-stemcell', false)
    end

    def ruby_bin
      environment['RUBY_BIN'] || File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
    end

    def hypervisor_for(infrastructure)
      environment['STEMCELL_HYPERVISOR'] || infrastructure.hypervisor
    end

    def source_root
      File.expand_path('../../../../..', __FILE__)
    end
  end
end
