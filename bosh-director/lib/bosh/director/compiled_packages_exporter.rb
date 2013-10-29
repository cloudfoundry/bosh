require 'bosh/director/tar_gzipper'
require 'bosh/director/compiled_package_downloader'

module Bosh::Director
  class CompiledPackagesExporter
    def initialize(compiled_package_group, blobstore_client)
      @compiled_package_group = compiled_package_group
      @blobstore_client = blobstore_client
    end

    def tgz_path
      downloader = CompiledPackageDownloader.new(@compiled_package_group, @blobstore_client)
      download_dir = downloader.download
      download_path = File.join(download_dir, 'compiled_packages.tgz')

      TarGzipper.new.compress(download_dir, '*', download_path)

      download_path
    end
  end
end
