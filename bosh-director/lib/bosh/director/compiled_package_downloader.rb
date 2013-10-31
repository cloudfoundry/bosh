require 'fileutils'
require 'tmpdir'
require 'bosh/director'
require 'bosh/director/compiled_package_manifest'

module Bosh::Director
  class CompiledPackageDownloader
    def initialize(compiled_package_group, blobstore_client)
      @compiled_package_group = compiled_package_group
      @blobstore_client = blobstore_client
    end

    def download
      @download_dir = Dir.mktmpdir

      blobs_path = File.join(@download_dir, 'compiled_packages', 'blobs')
      FileUtils.mkpath(blobs_path)

      @compiled_package_group.compiled_packages.each do |compiled_package|
        blobstore_id = compiled_package.blobstore_id
        File.open(File.join(blobs_path, blobstore_id), 'w') do |f|
          @blobstore_client.get(blobstore_id, f, sha1: compiled_package.sha1)
        end
      end

      @download_dir
    end

    def cleanup
      FileUtils.rm_rf(@download_dir)
    end
  end
end
