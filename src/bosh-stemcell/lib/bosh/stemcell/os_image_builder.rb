module Bosh::Stemcell
  class OsImageBuilder
    def initialize(dependencies = {})
      @environment = dependencies.fetch(:environment)
      @collection = dependencies.fetch(:collection)
      @runner = dependencies.fetch(:runner)
      @archive_handler = dependencies.fetch(:archive_handler)
    end

    def build(os_image_path)
      environment.prepare_build
      runner.configure_and_apply(collection.operating_system_stages, ENV['resume_from'])
      archive_handler.compress(environment.chroot_dir, os_image_path)
    end

    private

    attr_reader :environment, :collection, :runner, :archive_handler
  end
end
