module Bosh::Director
  module Jobs
    class UpdateRelease
      class PackageProcessor
        def initialize(
            release_version_model,
            release_model,
            name,
            version,
            manifest_packages,
            logger
        )

          @release_version_model = release_version_model
          @release_model = release_model
          @name = name
          @version = version
          @manifest_packages = manifest_packages
          @logger = logger

          @new_packages = []
          @existing_packages = []
          @registered_packages = []
        end

        attr_reader :logger, :manifest_packages

        def self.process(*args)
          PackageProcessor.new(*args).process
        end

        def process
          logger.info('Checking for new packages in release')

          manifest_packages.each do |package_meta|
            package_meta['compiled_package_sha1'] = package_meta['sha1']

            validate_package_fingerprint!(package_meta)

            packages = Models::Package.where(fingerprint: package_meta['fingerprint']).order_by(:id).all

            if packages.empty?
              @new_packages << package_meta
              next
            end

            existing_package = packages.find do |package|
              package.release_id == @release_model.id &&
                package.name == package_meta['name'] &&
                package.version == package_meta['version']
            end

            if existing_package
              use_existing_package(existing_package, packages, package_meta)
            else
              reuse_package_matching_fingerprint(packages, package_meta)
            end
          end

          return [@new_packages, @existing_packages, @registered_packages]
        end

        private

        def validate_package_fingerprint!(package_meta)
          # Checking whether we might have the same bits somewhere (in any release, not just the one being uploaded)
          @release_version_model.packages.select { |pv| pv.name == package_meta['name'] }.each do |package|
            if package.fingerprint != package_meta['fingerprint']
              raise ReleaseInvalidPackage, "package '#{package_meta['name']}' had different fingerprint in previously uploaded release '#{@name}/#{@version}'"
            end
          end
        end

        def use_existing_package(existing_package, packages, package_meta)
          if existing_package.blobstore_id.nil?
            packages.each do |package|
              next if package.blobstore_id.nil?

              package_meta['blobstore_id'] = package.blobstore_id
              package_meta['sha1'] = package.sha1
              break
            end
          end

          if existing_package.release_versions.include?(@release_version_model)
            @registered_packages << [existing_package, package_meta]
          else
            @existing_packages << [existing_package, package_meta]
          end
        end

        def reuse_package_matching_fingerprint(packages, package_meta)
          # We found a package with the same fingerprint but different
          # (release, name, version) tuple, so we need to make a copy
          # of the package blob and create a new db entry for it
          packages.each do |package|
            next if package.blobstore_id.nil?

            package_meta['blobstore_id'] = package.blobstore_id
            package_meta['sha1'] = package.sha1
            break
          end

          @new_packages << package_meta
        end
      end
    end
  end
end
