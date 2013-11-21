require 'bosh/director/compiled_package'

module Bosh::Director::CompiledPackage

  class CompiledPackageInserter
    def initialize(blobstore_client)
      @blobstore_client = blobstore_client
    end

    def insert(compiled_package, release_version)
      package = Bosh::Director::Models::Package[fingerprint: compiled_package.package_fingerprint]
      stemcell = Bosh::Director::Models::Stemcell[sha1: compiled_package.stemcell_sha1]

      unless Bosh::Director::Models::CompiledPackage[
        package: package,
        stemcell: stemcell,
        dependency_key: release_version.package_dependency_key(package.name),
      ]
        File.open(compiled_package.blob_path) do |f|
          @blobstore_client.create(f, compiled_package.blobstore_id)
        end

        Bosh::Director::Models::CompiledPackage.create(
          blobstore_id: compiled_package.blobstore_id,
          package: package,
          stemcell: stemcell,
          sha1: compiled_package.sha1,
          dependency_key: release_version.package_dependency_key(package.name),
          build: Bosh::Director::Models::CompiledPackage.generate_build_number(package, stemcell),
        )
      end

    end

  end
end
