module Bosh
  module Director
    module DeploymentPlan
      class ManifestMigrator
        def migrate(manifest, cloud_config)
          migrate_releases(manifest.manifest_hash)

          if cloud_config.nil? || cloud_config.empty? || cc_is_empty(cloud_config)
            cloud_config = cloud_manifest_from_deployment_manifest(manifest.manifest_hash)
          end

          [manifest, cloud_config]
        end

        def cc_is_empty(cc)
          cc.each_pair do |_,v|
            return false if !v.nil? && !v.empty?
          end
          return true
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
