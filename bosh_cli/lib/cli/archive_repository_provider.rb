module Bosh::Cli
  class ArchiveRepositoryProvider
    def initialize(archive_dir, blobstore)
      @archive_dir = archive_dir
      @blobstore = blobstore
    end

    def provide(resource)
      ArchiveRepository.new(@archive_dir, @blobstore, resource)
    end
  end
end
