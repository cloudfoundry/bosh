require 'bosh/dev/stemcell_builder_command'
require 'bosh/dev/stemcell_builder_options'
require 'bosh/dev/gems_generator'

module Bosh::Dev
  class StemcellRakeMethods
    def initialize(options)
      @stemcell_environment = options.fetch(:stemcell_environment)
      @stemcell_builder_options = StemcellBuilderOptions.new(args: options.fetch(:args))
    end

    def build_stemcell
      gems_generator = Bosh::Dev::GemsGenerator.new
      gems_generator.build_gems_into_release_dir

      stemcell_builder_command = StemcellBuilderCommand.new(stemcell_environment, stemcell_builder_options)
      stemcell_builder_command.build
    end

    private

    attr_reader :stemcell_environment,
                :stemcell_builder_options
  end
end
