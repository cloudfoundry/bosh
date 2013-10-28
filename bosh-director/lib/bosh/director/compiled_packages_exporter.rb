require 'bosh/director/tar_gzipper'

module Bosh::Director
  class CompiledPackageDownloader
  end

  class CompiledPackagesExporter
    def initialize(compiled_package_group, blobstore_client)
      @compiled_package_group = compiled_package_group
      @blobstore_client = blobstore_client
    end

    def tgz_path
      downloader = CompiledPackageDownloader.new(@compiled_package_group, @blobstore_client)
      download_dir = downloader.download

      TarGzipper.new.compress(download_dir, '*', File.join(download_dir, 'compiled_packages.tgz')).path
    end
  end
end
