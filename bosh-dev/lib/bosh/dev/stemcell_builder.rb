require 'bosh/dev/build'
require 'bosh/dev/gems_generator'
require 'bosh/dev/stemcell_environment'
require 'bosh/dev/stemcell_builder_options'
require 'bosh/dev/stemcell_builder_command'
require 'bosh/stemcell/infrastructure'

module Bosh::Dev
  class StemcellBuilder
    def initialize(infrastructure_name, candidate = Bosh::Dev::Build.candidate)
      @stemcell_environment = StemcellEnvironment.new(infrastructure_name: infrastructure_name)
      @infrastructure = Bosh::Stemcell::Infrastructure.for(infrastructure_name)
      @candidate = candidate
    end

    def build
      generate_gems

      stemcell_environment.sanitize

      stemcell_path = build_stemcell

      File.exist?(stemcell_path) || raise("#{stemcell_path} does not exist")

      stemcell_path
    end

    private

    attr_reader :candidate,
                :infrastructure,
                :stemcell_environment

    def generate_gems
      gems_generator = GemsGenerator.new
      gems_generator.build_gems_into_release_dir
    end

    def build_stemcell
      stemcell_builder_options = StemcellBuilderOptions.new(args: { tarball: candidate.download_release,
                                                                    stemcell_version: candidate.number,
                                                                    infrastructure: infrastructure })

      stemcell_builder_command = StemcellBuilderCommand.new(stemcell_environment, stemcell_builder_options)
      stemcell_builder_command.build
    end
  end
end
