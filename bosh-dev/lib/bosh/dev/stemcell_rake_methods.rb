require 'bosh/dev/build_from_spec'
require 'bosh/dev/stemcell_builder_options'
require 'bosh/dev/gems_generator'

module Bosh::Dev
  class StemcellRakeMethods
    def initialize(options)
      @environment = options.fetch(:environment) { ENV.to_hash }
      @args = options.fetch(:args)
      @stemcell_builder_options = StemcellBuilderOptions.new(args: args, environment: environment)
    end

    def build_basic_stemcell
      Bosh::Dev::GemsGenerator.new.build_gems_into_release_dir

      build_from_spec = BuildFromSpec.new(environment, "stemcell-#{args[:infrastructure]}", stemcell_builder_options.basic)
      build_from_spec.build
    end


    def build_micro_stemcell
      Bosh::Dev::GemsGenerator.new.build_gems_into_release_dir

      build_from_spec = BuildFromSpec.new(environment, "stemcell-#{args[:infrastructure]}", stemcell_builder_options.micro)
      build_from_spec.build
    end

    private

    attr_reader :environment, :args, :stemcell_builder_options
  end
end
