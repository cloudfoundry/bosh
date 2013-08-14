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

      build_from_spec = BuildFromSpec.new(environment, "stemcell-#{args[:infrastructure]}", basic_stemcell_options)
      build_from_spec.build
    end


    def build_micro_stemcell
      Bosh::Dev::GemsGenerator.new.build_gems_into_release_dir

      build_from_spec = BuildFromSpec.new(environment, "stemcell-#{args[:infrastructure]}", micro_bosh_options)
      build_from_spec.build
    end

    def micro_bosh_options
      options = basic_stemcell_options
      options[:stemcell_name] ||= 'micro-bosh-stemcell'
      options.merge({
                      bosh_micro_enabled: 'yes',
                      bosh_micro_package_compiler_path: File.join(source_root, 'package_compiler'),
                      bosh_micro_manifest_yml_path: File.join(source_root, "release/micro/#{args[:infrastructure]}.yml"),
                      bosh_micro_release_tgz_path: args.fetch(:tarball),
                    })
    end

    private

    attr_reader :environment, :args

    def basic_stemcell_options
      stemcell_builder_options = StemcellBuilderOptions.new(args: args, environment: environment)
      stemcell_builder_options.to_h
    end

    def source_root
      File.expand_path('../../../../..', __FILE__)
    end
  end
end
