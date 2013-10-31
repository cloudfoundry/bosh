require 'bosh/director'
require 'bosh/director/compiled_package_yaml_writer'

require 'fileutils'
require 'tmpdir'

module Bosh::Director
  class CompiledPackageDownloader
    def initialize(compiled_package_group, blobstore_client)
      @compiled_package_group = compiled_package_group
      @blobstore_client = blobstore_client
    end

    def download
      @download_dir = Dir.mktmpdir

      FileUtils.mkdir_p(File.join(@download_dir, 'compiled_packages', 'blobs'))

      @compiled_package_group.compiled_packages.each do |compiled_package|
        blobstore_id = compiled_package.blobstore_id

        compiled_package_blob = File.open(File.join(@download_dir, 'compiled_packages', 'blobs', blobstore_id), 'w')
        @blobstore_client.get(blobstore_id, compiled_package_blob)
        compiled_package_blob.close
      end

      CompiledPackageYamlWriter.new(@compiled_package_group, File.join(@download_dir, 'compiled_packages')).write
      @download_dir
    end

    def cleanup
      FileUtils.rm_rf(@download_dir)
    end
  end
end
