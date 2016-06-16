module Bosh::Cli
  class ArchiveRepositoryProvider
    def initialize(archive_dir, artifacts_dir, blobstore)
      @archive_dir = archive_dir
      @artifacts_dir = artifacts_dir
      @blobstore = blobstore
    end

    def get(resource)
      ArchiveRepository.new(@archive_dir, @artifacts_dir, @blobstore, resource)
    end
  end
end
