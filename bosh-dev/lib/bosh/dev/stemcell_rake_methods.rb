require 'bosh/dev/stemcell_builder_command'
require 'bosh/dev/stemcell_builder_options'
require 'bosh/dev/gems_generator'

module Bosh::Dev
  class StemcellRakeMethods
    def initialize(options)
      @stemcell_environment = options.fetch(:stemcell_environment)
      @args = options.fetch(:args)

      @environment = options.fetch(:environment) { ENV.to_hash }
      @stemcell_builder_options = StemcellBuilderOptions.new(args: args, environment: environment)
    end

    def build_stemcell
      Bosh::Dev::GemsGenerator.new.build_gems_into_release_dir

      stemcell_builder_command = StemcellBuilderCommand.new(environment,
                                                            "stemcell-#{args[:infrastructure]}",
                                                            stemcell_environment.build_path,
                                                            stemcell_environment.work_path,
                                                            stemcell_builder_options.default)
      stemcell_builder_command.build
    end

    private

    attr_reader :environment,
                :stemcell_environment,
                :args,
                :stemcell_builder_options
  end
end
