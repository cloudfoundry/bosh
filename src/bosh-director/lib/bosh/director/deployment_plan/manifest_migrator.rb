module Bosh
  module Director
    module DeploymentPlan
      class ManifestMigrator
        def migrate(manifest, cloud_config)
          migrate_releases(manifest.raw_manifest_hash)
          migrate_releases(manifest.hybrid_manifest_hash)

          if cloud_config.nil? || cloud_config.empty?
            cloud_config = cloud_manifest_from_deployment_manifest(manifest.hybrid_manifest_hash)
          end

          [manifest, cloud_config]
        end

        private

        def cloud_manifest_from_deployment_manifest(hybrid_deployment_manifest)
          cloud_manifest = {}
          ManifestValidator::CLOUD_MANIFEST_KEYS.each do |key|
            cloud_manifest[key] = hybrid_deployment_manifest[key] if hybrid_deployment_manifest.has_key? key
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
