module Bosh::Director
  module Jobs
    class UpdateRelease
      class PackageProcessor
        class << self
          def process(release_version_model, release_model, name, version, manifest_packages, logger, fix)
            new_packages = []
            existing_packages = []
            registered_packages = []

            logger.info('Checking for new packages in release')

            manifest_packages.each do |package_meta|
              package_meta['compiled_package_sha1'] = package_meta['sha1']

              validate_package_fingerprint!(package_meta, release_version_model, name, version)

              packages = Models::Package.where(fingerprint: package_meta['fingerprint']).order_by(:id).all

              existing_package = packages.find do |package|
                package.release_id == release_model.id &&
                  package.name == package_meta['name'] &&
                  package.version == package_meta['version']
              end

              if !existing_package&.blobstore_id && !fix
                reuse_package_matching_fingerprint(packages, package_meta)
              end

              unless existing_package
                new_packages << package_meta
                next
              end

              if existing_package.release_versions.include?(release_version_model)
                registered_packages << [existing_package, package_meta]
              else
                existing_packages << [existing_package, package_meta]
              end
            end

            [new_packages, existing_packages, registered_packages]
          end

          private

          def validate_package_fingerprint!(package_meta, release_version_model, name, version)
            # Checking whether we might have the same bits somewhere (in any release, not just the one being uploaded)
            release_version_model.packages.select { |pv| pv.name == package_meta['name'] }.each do |package|
              next unless package.fingerprint != package_meta['fingerprint']

              msg = "package '#{package_meta['name']}' had different fingerprint "\
                    "in previously uploaded release '#{name}/#{version}'"
              raise ReleaseInvalidPackage, msg
            end
          end

          def reuse_package_matching_fingerprint(packages, package_meta)
            # We found a package with the same fingerprint but different
            # (release, name, version) tuple, so we need to make a copy
            # of the package blob and create a new db entry for it
            reusable_matching_package = packages.find(&:blobstore_id)
            return unless reusable_matching_package

            package_meta['blobstore_id'] = reusable_matching_package.blobstore_id
            package_meta['sha1'] = reusable_matching_package.sha1
          end
        end
      end
    end
  end
end
