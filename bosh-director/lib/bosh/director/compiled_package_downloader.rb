require 'bosh/director'
require 'bosh/director/compiled_package_manifest'

require 'fileutils'
require 'tmpdir'
require 'pathname'

module Bosh::Director
  class CompiledPackageDownloader
    def initialize(compiled_package_group, blobstore_client)
      @compiled_package_group = compiled_package_group
      @blobstore_client = blobstore_client
    end

    def download
      @download_dir = Pathname.new(Dir.mktmpdir)

      blobs_path = @download_dir.join('compiled_packages', 'blobs')
      blobs_path.mkpath

      @compiled_package_group.compiled_packages.each do |compiled_package|
        blobstore_id = compiled_package.blobstore_id

        compiled_package_blob = blobs_path.join(blobstore_id).open('w')
        @blobstore_client.get(blobstore_id, compiled_package_blob)
        compiled_package_blob.close
      end

      CompiledPackageManifest.new(@compiled_package_group, @download_dir.join('compiled_packages')).write
      @download_dir
    end

    def cleanup
      @download_dir.rmtree
    end
  end
end
