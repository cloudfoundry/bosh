require 'bosh/dev/build'
require 'bosh/dev/gems_generator'
require 'bosh/dev/stemcell_builder_command'
require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Dev
  class StemcellBuilder
    def initialize(build, infrastructure_name, operating_system_name)
      @build = build
      @infrastructure = Bosh::Stemcell::Infrastructure.for(infrastructure_name)
      @operating_system = Bosh::Stemcell::OperatingSystem.for(operating_system_name)
    end

    def build_stemcell
      generate_gems

      stemcell_path = run_stemcell_builder_command

      File.exist?(stemcell_path) || raise("#{stemcell_path} does not exist")

      stemcell_path
    end

    private

    attr_reader :build, :infrastructure, :operating_system

    def generate_gems
      gems_generator = GemsGenerator.new
      gems_generator.build_gems_into_release_dir
    end

    def run_stemcell_builder_command
      stemcell_builder_command = StemcellBuilderCommand.new(build, infrastructure, operating_system)
      stemcell_builder_command.build
    end
  end
end
