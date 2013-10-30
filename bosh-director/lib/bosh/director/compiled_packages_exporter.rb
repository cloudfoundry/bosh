require 'bosh/director/tar_gzipper'
require 'bosh/director/compiled_package_downloader'

module Bosh::Director
  class CompiledPackagesExporter
    def initialize(compiled_package_group, blobstore_client, output_dir)
      @compiled_package_group = compiled_package_group
      @blobstore_client = blobstore_client
      @output_dir = output_dir
    end

    def tgz_path
      downloader = CompiledPackageDownloader.new(@compiled_package_group, @blobstore_client)
      download_dir = downloader.download
      download_path = File.join(@output_dir, 'compiled_packages.tgz')

      TarGzipper.new.compress(download_dir, 'compiled_packages', download_path)

      downloader.cleanup

      download_path
    end
  end
end
