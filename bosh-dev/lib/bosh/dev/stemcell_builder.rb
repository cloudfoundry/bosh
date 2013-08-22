require 'bosh/dev/build'
require 'bosh/dev/gems_generator'
require 'bosh/dev/stemcell_builder_options'
require 'bosh/dev/stemcell_builder_command'
require 'bosh/stemcell/infrastructure'

module Bosh::Dev
  class StemcellBuilder
    def initialize(build, infrastructure_name)
      @build = build
      @infrastructure = Bosh::Stemcell::Infrastructure.for(infrastructure_name)
    end

    def build_stemcell
      generate_gems

      stemcell_path = run_stemcell_builder_command

      File.exist?(stemcell_path) || raise("#{stemcell_path} does not exist")

      stemcell_path
    end

    private

    attr_reader :build, :infrastructure

    def generate_gems
      gems_generator = GemsGenerator.new
      gems_generator.build_gems_into_release_dir
    end

    def run_stemcell_builder_command
      stemcell_builder_command = StemcellBuilderCommand.new(build, infrastructure)
      stemcell_builder_command.build
    end
  end
end
