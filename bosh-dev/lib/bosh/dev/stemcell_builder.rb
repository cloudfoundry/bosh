require 'bosh/dev/build'
require 'bosh/dev/gems_generator'
require 'bosh/stemcell/builder_command'

module Bosh::Dev
  class StemcellBuilder
    def initialize(build, infrastructure_name, operating_system_name)
      @stemcell_builder_command = Bosh::Stemcell::BuilderCommand.new(
        infrastructure_name:   infrastructure_name,
        operating_system_name: operating_system_name,
        version:               build.number,
        release_tarball_path:  build.download_release,
      )
    end

    def build_stemcell
      unless @stemcell_path
        GemsGenerator.new.build_gems_into_release_dir

        @stemcell_path = stemcell_builder_command.build
      end

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
