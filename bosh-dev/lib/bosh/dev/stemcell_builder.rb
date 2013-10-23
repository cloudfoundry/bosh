require 'bosh/dev/build'
require 'bosh/dev/gem_components'
require 'bosh/stemcell/builder_command'

module Bosh::Dev
  class StemcellBuilder
    def self.for_candidate_build(infrastructure_name, operating_system_name)
      new(
        ENV.to_hash,
        Build.candidate,
        infrastructure_name,
        operating_system_name,
      )
    end

    def initialize(env, build, infrastructure_name, operating_system_name)
      @build_number = build.number
      @stemcell_builder_command = Bosh::Stemcell::BuilderCommand.new(
        env,
        infrastructure_name:   infrastructure_name,
        operating_system_name: operating_system_name,
        version:               build.number,
        release_tarball_path:  build.release_tarball_path,
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
