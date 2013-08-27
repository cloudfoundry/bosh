require 'bosh/dev/build'
require 'bosh/dev/gems_generator'
require 'bosh/stemcell/builder_command'

module Bosh::Dev
  class StemcellBuilder
    def initialize(build, infrastructure_name, operating_system_name)
      @build = build
      @infrastructure_name = infrastructure_name
      @operating_system_name = operating_system_name
    end

    def build_stemcell
      generate_gems

      stemcell_path = run_stemcell_builder_command

      File.exist?(stemcell_path) || raise("#{stemcell_path} does not exist")

      stemcell_path
    end

    private

    attr_reader :build, :infrastructure_name, :operating_system_name

    def generate_gems
      gems_generator = GemsGenerator.new
      gems_generator.build_gems_into_release_dir
    end

    def run_stemcell_builder_command
      stemcell_builder_command = Bosh::Stemcell::BuilderCommand.new(
        infrastructure_name: infrastructure_name,
        operating_system_name: operating_system_name,
        version: build.number,
        release_tarball_path: build.download_release,
      )
      stemcell_builder_command.build
    end
  end
end
