require 'fileutils'
require 'rbconfig'
require 'rugged'

require 'bosh_agent/version'
require 'bosh/dev/build_from_spec'
require 'bosh/dev/gems_generator'
require 'bosh/dev/build'
require 'bosh/dev/micro_bosh_release'
require 'bosh/stemcell/infrastructure'

module Bosh::Dev
  class StemcellRakeMethods
    def initialize(options)
      @environment = options.fetch(:environment) { ENV.to_hash }
      @args = options.fetch(:args)
    end

    def build_basic_stemcell
      options = default_options

      Bosh::Dev::GemsGenerator.new.build_gems_into_release_dir

      build_from_spec = BuildFromSpec.new(environment, "stemcell-#{args[:infrastructure]}", options)
      build_from_spec.build
    end

    def build_micro_stemcell
      options = default_options

      Bosh::Dev::GemsGenerator.new.build_gems_into_release_dir

      release_tarball = args.fetch(:tarball)

      options[:stemcell_name] ||= 'micro-bosh-stemcell'

      options = options.merge(bosh_micro_options(args[:infrastructure], release_tarball))

      build_from_spec = BuildFromSpec.new(environment, "stemcell-#{args[:infrastructure]}", options)
      build_from_spec.build
    end

    def bosh_micro_options(infrastructure, tarball)
      {
        bosh_micro_enabled: 'yes',
        bosh_micro_package_compiler_path: File.join(source_root, 'package_compiler'),
        bosh_micro_manifest_yml_path: File.join(source_root, "release/micro/#{infrastructure}.yml"),
        bosh_micro_release_tgz_path: tarball,
      }
    end

    def default_options
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

    private

    attr_reader :environment, :args

    def source_root
      File.expand_path('../../../../..', __FILE__)
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
