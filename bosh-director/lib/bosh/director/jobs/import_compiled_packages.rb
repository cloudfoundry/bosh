require 'bosh/director/compiled_package/compiled_packages_export'
require 'bosh/director/compiled_package/compiled_package_inserter'

module Bosh::Director
  module Jobs
    class ImportCompiledPackages < BaseJob
      @queue = :normal

      def self.job_type
        :import_compiled_packages
      end

      def initialize(export_dir, options={})
        @export_dir = export_dir

        @blobstore_client = options.fetch(:blobstore_client) { Bosh::Director::App.instance.blobstores.blobstore }
      end

      def perform
        export = Bosh::Director::CompiledPackage::CompiledPackagesExport.new(file: export_path)

        export.extract do |manifest, packages|
          packages.each do |package|
            File.open(package.blob_path) do |f|
              blobstore_client.create(f, package.blobstore_id)
            end
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
      ensure
        FileUtils.rm_rf(@export_dir)
      end

      private

      def export_path
        File.join(@export_dir, 'compiled_packages_export.tgz')
      end

      attr_reader :blobstore_client
      attr_reader :export_dir
    end
  end
end
