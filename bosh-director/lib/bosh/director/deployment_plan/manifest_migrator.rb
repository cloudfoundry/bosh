module Bosh
  module Director
    module DeploymentPlan
      class ManifestMigrator
        def migrate(manifest_hash, cloud_config)
          migrate_releases(manifest_hash)

          if cloud_config.nil?
            cloud_config = cloud_manifest_from_deployment_manifest(manifest_hash)
          end

          [manifest_hash, cloud_config]
        end

        private

        def cloud_manifest_from_deployment_manifest(deployment_manifest)
          cloud_manifest = {}
          ManifestValidator::CLOUD_MANIFEST_KEYS.each do |key|
            cloud_manifest[key] = deployment_manifest[key] if deployment_manifest.has_key? key
          end
          cloud_manifest
        end

        def migrate_releases(manifest_hash)
          if manifest_hash.has_key?('release')
            raise(
              Bosh::Director::DeploymentAmbiguousReleaseSpec,
              "Deployment manifest contains both 'release' and 'releases' sections, please use one of the two."
            ) if manifest_hash.has_key?('releases')

            legacy_release = manifest_hash.delete('release')
            manifest_hash['releases'] = [legacy_release].compact
          end
        end
      end
    end
  end
end
