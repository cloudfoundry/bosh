require 'bosh/dev/build'
require 'bosh/dev/gem_components'
require 'bosh/stemcell/builder_command'
require 'bosh/stemcell/definition'

module Bosh::Dev
  class StemcellBuilder
    def self.for_candidate_build(infrastructure_name, operating_system_name, agent_name)
      new(
        ENV.to_hash,
        Build.candidate,
        Bosh::Stemcell::Definition.for(infrastructure_name, operating_system_name, agent_name)
      )
    end

    def initialize(env, build, definition)
      @build_number = build.number
      @stemcell_builder_command = Bosh::Stemcell::BuilderCommand.new(
        env,
        definition,
        build.number,
        build.release_tarball_path,
      )
    end

    def build_stemcell
      gem_components = GemComponents.new(@build_number)
      gem_components.build_release_gems

      @stemcell_path = stemcell_builder_command.build

      File.exist?(@stemcell_path) || raise("#{@stemcell_path} does not exist")

      @stemcell_path
    end

    def stemcell_chroot_dir
      stemcell_builder_command.chroot_dir
    end

    private

    attr_reader :stemcell_builder_command
  end
end
