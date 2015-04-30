module Bosh
  module Director
    module DeploymentPlan
      class ManifestMigrator
        def migrate(manifest_hash, cloud_config)
          migrate_releases(manifest_hash)

          if cloud_config.nil?
            cloud_manifest = cloud_manifest_from_deployment_manifest(manifest_hash)
          else
            verify_deployment_without_cloud_config(manifest_hash)
            cloud_manifest = cloud_config.manifest
          end

          [manifest_hash, cloud_manifest]
        end

        private

        CLOUD_MANIFEST_KEYS = ['resource_pools','compilation','disk_pools','networks']
        def cloud_manifest_from_deployment_manifest(deployment_manifest)
          cloud_manifest = {}
          CLOUD_MANIFEST_KEYS.each do |key|
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

        def verify_deployment_without_cloud_config(manifest_hash)
          deployment_cloud_properties = manifest_hash.keys & CLOUD_MANIFEST_KEYS
          if deployment_cloud_properties.any?
            raise(
              Bosh::Director::DeploymentInvalidProperty,
              "Deployment manifest should not contain cloud config properties: #{deployment_cloud_properties}"
            )
          end
        end
      end
    end
  end
end
