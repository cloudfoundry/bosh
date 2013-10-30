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

      compiled_packages = {'compiled_packages' => []}
      Dir.mkdir(File.join(@download_dir, 'blobs'))

      @compiled_package_group.compiled_packages.each do |compiled_package|
        blobstore_id = compiled_package.blobstore_id

        compiled_packages['compiled_packages'] << {
          'package_name' => compiled_package.package.name,
          'package_fingerprint' => compiled_package.package.fingerprint,
          'stemcell_sha1' => @compiled_package_group.stemcell_sha1,
          'blobstore_id' => blobstore_id,
        }
        compiled_package_blob = File.open(File.join(@download_dir, 'blobs', blobstore_id), 'w')
        @blobstore_client.get(blobstore_id, compiled_package_blob)
        compiled_package_blob.close
      end

      File.open(File.join(@download_dir, 'compiled_packages.yml'), 'w') do |f|
        f.write(YAML.dump(compiled_packages))
      end

      @download_dir
    end

    def cleanup
      FileUtils.rm_rf(@download_dir)
    end
  end
end
