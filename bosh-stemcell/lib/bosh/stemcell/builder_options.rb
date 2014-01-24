require 'rbconfig'
require 'bosh_agent/version'
require 'bosh/stemcell/archive_filename'

require 'forwardable'

module Bosh::Stemcell
  class BuilderOptions
    extend Forwardable

    def initialize(env, definition, version, tarball, disk_size = nil)
      @environment = env
      @definition = definition

      @stemcell_version = version
      @image_create_disk_size = disk_size || infrastructure.default_disk_size
      @bosh_micro_release_tgz_path = tarball
    end

    def default
      stemcell_name = "bosh-#{infrastructure.name}-#{infrastructure.hypervisor}-#{operating_system.name}"
      stemcell_name += "-#{agent.name}_agent" unless agent.name == 'ruby'

      {
        'stemcell_name' => stemcell_name,
        'stemcell_tgz' => archive_filename.to_s,
        'stemcell_image_name' => stemcell_image_name,
        'stemcell_version' => stemcell_version,
        'stemcell_hypervisor' => infrastructure.hypervisor,
        'stemcell_infrastructure' => infrastructure.name,
        'stemcell_operating_system' => operating_system.name,
        'bosh_protocol_version' => Bosh::Agent::BOSH_PROTOCOL,
        'ruby_bin' => ruby_bin,
        'bosh_release_src_dir' => File.join(source_root, 'release/src/bosh'),
        'bosh_agent_src_dir' => File.join(source_root, 'bosh_agent'),
        'go_agent_src_dir' => File.join(source_root, 'go_agent'),
        'image_create_disk_size' => image_create_disk_size
      }.merge(bosh_micro_options).merge(environment_variables).merge(vsphere_options)
    end

    private

    def_delegators(
      :@definition,
      :infrastructure,
      :operating_system,
      :agent,
    )

    attr_reader(
      :environment,
      :stemcell_version,
      :definition,
      :image_create_disk_size,
      :bosh_micro_release_tgz_path
    )

    def vsphere_options
      if infrastructure.name == 'vsphere'
        { 'image_vsphere_ovf_ovftool_path' => environment['OVFTOOL'] }
      else
        {}
      end
    end

    def environment_variables
      {
        'UBUNTU_ISO' => environment['UBUNTU_ISO'],
        'UBUNTU_MIRROR' => environment['UBUNTU_MIRROR'],
      }
    end

    def bosh_micro_options
      {
        'bosh_micro_enabled' => 'yes',
        'bosh_micro_package_compiler_path' => File.join(source_root, 'bosh-release'),
        'bosh_micro_manifest_yml_path' => File.join(source_root, 'release', 'micro', "#{infrastructure.name}.yml"),
        'bosh_micro_release_tgz_path' => bosh_micro_release_tgz_path,
      }
    end

    def archive_filename
      ArchiveFilename.new(stemcell_version, definition, 'bosh-stemcell', false)
    end

    def stemcell_image_name
      "#{infrastructure.name}-#{infrastructure.hypervisor}-#{operating_system.name}.raw"
    end

    def ruby_bin
      environment['RUBY_BIN'] || File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
    end

    def source_root
      File.expand_path('../../../../..', __FILE__)
    end
  end
end
