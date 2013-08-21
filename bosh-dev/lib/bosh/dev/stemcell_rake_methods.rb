require 'bosh/dev/stemcell_builder_command'
require 'bosh/dev/stemcell_builder_options'
require 'bosh/dev/gems_generator'

module Bosh::Dev
  class StemcellRakeMethods
    def initialize(options)
      @environment = options.fetch(:environment) { ENV.to_hash }
      @args = options.fetch(:args)
      @stemcell_builder_options = StemcellBuilderOptions.new(args: args, environment: environment)
    end

    def build_stemcell
      Bosh::Dev::GemsGenerator.new.build_gems_into_release_dir

      stemcell_builder_command = StemcellBuilderCommand.new(environment, "stemcell-#{args[:infrastructure]}", stemcell_builder_options.default)
      stemcell_builder_command.build
    end

    private

    attr_reader :environment, :args, :stemcell_builder_options
  end
end
