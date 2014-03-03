require 'fileutils'

require 'bosh/core/shell'


module Bosh::Stemcell
  class BuilderCommand

    BASE_OS_FILE_PATH = '/tmp/base_os_image.tgz'

    def initialize(helper, stage_collection, stage_runner)
      @helper = helper
      @collection = stage_collection
      @runner = stage_runner
      @shell = Bosh::Core::Shell.new
    end

    def build_base_image_for_stemcell
      helper.prepare_build

      operating_system_stages = @collection.operating_system_stages

      @runner.configure_and_apply(operating_system_stages)
    end

    def build
      helper.prepare_build

      # download_and_extract_base_os_image(nil)

      agent_stages = @collection.agent_stages
      infrastructure_stages = @collection.infrastructure_stages

      all_stages = agent_stages + infrastructure_stages

      @runner.configure_and_apply(all_stages)
      shell.run(helper.rspec_command)

      helper.stemcell_file
    end

    def chroot_dir
      helper.chroot_dir
    end

    private

    attr_reader(
      :shell,
      :helper,
    )
  end
end
