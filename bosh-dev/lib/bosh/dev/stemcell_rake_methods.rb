require 'bosh/dev/stemcell_builder_command'
require 'bosh/dev/gems_generator'

module Bosh::Dev
  class StemcellRakeMethods
    def initialize(options)
      @stemcell_environment = options.fetch(:stemcell_environment)
      @stemcell_builder_options = options.fetch(:stemcell_builder_options)
    end

    def build_stemcell
      stemcell_builder_command = StemcellBuilderCommand.new(stemcell_environment, stemcell_builder_options)
      stemcell_builder_command.build
    end

    private

    attr_reader :stemcell_environment, :stemcell_builder_options
  end
end
