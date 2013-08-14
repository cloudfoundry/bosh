require 'bosh/dev/build_from_spec'
require 'bosh/dev/stemcell_builder_options'
require 'bosh/dev/gems_generator'
require 'bosh/dev/micro_bosh_release'

module Bosh::Dev
  class StemcellRakeMethods
    def initialize(options)
      @environment = options.fetch(:environment) { ENV.to_hash }
      @args = options.fetch(:args)
    end

    def build_basic_stemcell
      Bosh::Dev::GemsGenerator.new.build_gems_into_release_dir

      stemcell_builder_options = StemcellBuilderOptions.new(args: args, environment: environment)
      options = stemcell_builder_options.to_h
      build_from_spec = BuildFromSpec.new(environment, "stemcell-#{args[:infrastructure]}", options)
      build_from_spec.build
    end

    def build_micro_stemcell
      Bosh::Dev::GemsGenerator.new.build_gems_into_release_dir

      stemcell_builder_options = StemcellBuilderOptions.new(args: args, environment: environment)
      options = stemcell_builder_options.to_h
      options[:stemcell_name] ||= 'micro-bosh-stemcell'
      options = options.merge(bosh_micro_options(args[:infrastructure], args.fetch(:tarball)))

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

    private

    attr_reader :environment, :args

    def source_root
      File.expand_path('../../../../..', __FILE__)
    end
  end
end
