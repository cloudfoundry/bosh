require 'bosh/director/core/tar_gzipper'
require 'bosh/director/compiled_package_downloader'

module Bosh::Director
  class CompiledPackagesExporter
    def initialize(compiled_package_group, blobstore_client)
      @compiled_package_group = compiled_package_group
      @blobstore_client = blobstore_client
    end

    def export(output_path)
      downloader = CompiledPackageDownloader.new(@compiled_package_group, @blobstore_client)
      download_dir = downloader.download

      manifest = CompiledPackageManifest.new(@compiled_package_group)
      manifest.write(File.join(download_dir, 'compiled_packages.MF'))

      archiver = Core::TarGzipper.new
      archiver.compress(download_dir, ['compiled_packages', 'compiled_packages.MF'], output_path)
    ensure
      downloader.cleanup
    end
  end
end
