require 'tmpdir'

module Bosh::Director
  class CompiledPackageDownloader
    def initialize(compiled_package_group, blobstore_client)
      @compiled_package_group = compiled_package_group
      @blobstore_client = blobstore_client
    end

    def download
      temp_dir = Dir.mktmpdir

      compiled_packages = {'compiled_packages' => []}
      Dir.mkdir(File.join(temp_dir, 'blobs'))

      @compiled_package_group.compiled_packages.each do |compiled_package|
        blobstore_id = compiled_package.blobstore_id

        compiled_packages['compiled_packages'] << {'name' => compiled_package.package.name, 'blobstore_id' => blobstore_id}
        compiled_package_blob = File.open(File.join(temp_dir, 'blobs', blobstore_id), 'w')
        @blobstore_client.get(blobstore_id, compiled_package_blob)
        compiled_package_blob.close
      end

      File.open(File.join(temp_dir, 'compiled_packages.yml'), 'w').write(YAML.dump(compiled_packages))

      temp_dir
    end
  end
end
