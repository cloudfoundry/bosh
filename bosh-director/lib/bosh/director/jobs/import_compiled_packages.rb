require 'bosh/director/compiled_package/compiled_packages_export'
require 'bosh/director/compiled_package/compiled_package_inserter'

module Bosh::Director::Jobs
  class ImportCompiledPackages < BaseJob
    @queue = :normal

    def self.job_type
      :import_compiled_packages
    end

    def initialize(options={})
      @export_path = options.fetch(:export_path)
      @blobstore_client = options.fetch(:blobstore_client) { App.instance.blobstores.blobstore }
    end

    def perform
      export = Bosh::Director::CompiledPackage::CompiledPackagesExport.new(file: export_path)

      export.extract do |manifest, packages|
        packages.each do |package|
          blobstore_client.create_file(package.blobstore_id, package.blob_path)
        end

        release_name = manifest.fetch('release_name')
        release_version = manifest.fetch('release_version')

        release = Bosh::Director::Models::Release[name: release_name]
        release_version = Bosh::Director::Models::ReleaseVersion[release_id: release.id, version: release_version]

        inserter = Bosh::Director::CompiledPackage::CompiledPackageInserter.new

        Bosh::Director::Config.db.transaction do
          packages.each do |package|
            inserter.insert(package, release_version)
          end
        end
      end
    end

    private

    attr_reader :blobstore_client
    attr_reader :export_path
  end
end

