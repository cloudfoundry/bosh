require 'rbconfig'
require 'forwardable'
require 'bosh/stemcell/archive_filename'

module Bosh::Stemcell
  class BuilderOptions
    extend Forwardable

    def initialize(dependencies = {})
      @environment = dependencies.fetch(:env)
      @definition = dependencies.fetch(:definition)

      @stemcell_version = dependencies.fetch(:version)
      @image_create_disk_size = dependencies.fetch(:disk_size, infrastructure.default_disk_size)
      @bosh_micro_release_tgz_path = dependencies.fetch(:release_tarball)
      @os_image_tgz_path = dependencies.fetch(:os_image_tarball)
    end

    def default
      {
        'stemcell_name' => "bosh-#{@definition.stemcell_name}",
        'stemcell_tgz' => archive_filename.to_s,
        'stemcell_image_name' => stemcell_image_name,
        'stemcell_version' => stemcell_version,
        'stemcell_hypervisor' => infrastructure.hypervisor,
        'stemcell_infrastructure' => infrastructure.name,
        'stemcell_operating_system' => operating_system.name,
        'stemcell_operating_system_version' => operating_system.version,
        'ruby_bin' => ruby_bin,
        'bosh_release_src_dir' => File.join(source_root, 'release/src/bosh'),
        'agent_src_dir' => File.join(source_root, 'go/src/github.com/cloudfoundry/bosh-agent'),
        'image_create_disk_size' => image_create_disk_size,
        'os_image_tgz' => os_image_tgz_path,
      }.merge(bosh_micro_options).merge(environment_variables).merge(ovf_options)
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
      :bosh_micro_release_tgz_path,
      :os_image_tgz_path,
    )

    def ovf_options
      if infrastructure.name == 'vsphere' || infrastructure.name == 'vcloud'
        { 'image_ovftool_path' => environment['OVFTOOL'] }
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
      ArchiveFilename.new(stemcell_version, definition, 'bosh-stemcell')
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
