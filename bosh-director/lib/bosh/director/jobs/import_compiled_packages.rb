require 'bosh/director/compiled_package/compiled_packages_export'
require 'bosh/director/compiled_package/compiled_package_inserter'

module Bosh::Director
  module Jobs
    class ImportCompiledPackages < BaseJob
      @queue = :normal

      def self.job_type
        :import_compiled_packages
      end

      def initialize(export_dir)
        @export_dir = export_dir

        @blobstore_client = Bosh::Director::App.instance.blobstores.blobstore
      end

      def perform
        export = Bosh::Director::CompiledPackage::CompiledPackagesExport.new(file: export_path)

        export.extract do |manifest, packages|
          release_name = manifest.fetch('release_name')
          release_version_version = manifest.fetch('release_version')

          release = Bosh::Director::Models::Release[name: release_name]
          if release.nil?
            raise ReleaseNotFound, "Release version `#{release}/#{release_version_version}' doesn't exist"
          end

          release_version = Bosh::Director::Api::ReleaseManager.new.find_version(release, release_version_version)
          inserter = Bosh::Director::CompiledPackage::CompiledPackageInserter.new(@blobstore_client)

          packages.each { |p| p.check_blob_sha }

          packages.each do |package|
            inserter.insert(package, release_version)
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
