module Bosh
  module Director
    module DeploymentPlan
      class ManifestMigrator
        def migrate(manifest_hash)
          if manifest_hash.has_key?('release')
            raise(
              Bosh::Director::DeploymentAmbiguousReleaseSpec,
              "Deployment manifest contains both 'release' and 'releases' sections, please use one of the two."
            ) if manifest_hash.has_key?('releases')

            legacy_release = manifest_hash.delete('release')
            manifest_hash['releases'] = [legacy_release].compact
          end

          manifest_hash
        end
      end
    end
  end
end
