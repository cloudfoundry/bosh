require 'rbconfig'

require 'bosh_agent/version'
require 'bosh/stemcell/archive_filename'

module Bosh::Stemcell
  class BuilderOptions
    def initialize(options)
      @environment = ENV.to_hash
      @infrastructure = options.fetch(:infrastructure)
      @operating_system = options.fetch(:operating_system)

      @stemcell_version = options.fetch(:stemcell_version)
      @image_create_disk_size = options.fetch(:disk_size, infrastructure.default_disk_size)
      @bosh_micro_release_tgz_path = options.fetch(:tarball)
    end

    def spec_name
      ['stemcell', infrastructure.name, hypervisor_for(infrastructure), operating_system.name].join('-')
    end

    def default
      {
        'stemcell_name' => 'bosh-stemcell',
        'stemcell_tgz' => archive_filename.to_s,
        'stemcell_version' => stemcell_version,
        'stemcell_hypervisor' => hypervisor_for(infrastructure),
        'stemcell_infrastructure' => infrastructure.name,
        'system_parameters_infrastructure' => infrastructure.name,
        'bosh_protocol_version' => Bosh::Agent::BOSH_PROTOCOL,
        'ruby_bin' => ruby_bin,
        'bosh_release_src_dir' => File.join(source_root, 'release/src/bosh'),
        'bosh_agent_src_dir' => File.join(source_root, 'bosh_agent'),
        'image_create_disk_size' => image_create_disk_size
      }.merge(bosh_micro_options).merge(environment_variables).merge(vsphere_options)
    end

    private

    attr_reader :environment,
                :infrastructure,
                :operating_system,
                :stemcell_version,
                :image_create_disk_size,
                :bosh_micro_release_tgz_path

    def vsphere_options
      infrastructure.name == 'vsphere' ? { 'image_vsphere_ovf_ovftool_path' => environment['OVFTOOL'] } : {}
    end

    def environment_variables
      {
        'UBUNTU_ISO' => environment['UBUNTU_ISO'],
        'UBUNTU_MIRROR' => environment['UBUNTU_MIRROR'],
        'TW_LOCAL_PASSPHRASE' => environment['TW_LOCAL_PASSPHRASE'],
        'TW_SITE_PASSPHRASE' => environment['TW_SITE_PASSPHRASE'],
      }
    end

    def bosh_micro_options
      {
        'bosh_micro_enabled' => 'yes',
        'bosh_micro_package_compiler_path' => File.join(source_root, 'package_compiler'),
        'bosh_micro_manifest_yml_path' => File.join(source_root, 'release', 'micro', "#{infrastructure.name}.yml"),
        'bosh_micro_release_tgz_path' => bosh_micro_release_tgz_path,
      }
    end

    def archive_filename
      ArchiveFilename.new(stemcell_version, infrastructure, operating_system, 'bosh-stemcell', false)
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
