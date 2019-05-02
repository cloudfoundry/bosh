module Bosh
  module Director
    module DeploymentPlan
      class ManifestValidator

        CLOUD_MANIFEST_KEYS = ['compilation', 'disk_pools', 'networks']

        def validate(manifest, cloud_config)
          raise_if_has_key(manifest, 'vm_types')
          raise_if_has_key(manifest, 'azs')
          raise_if_has_key(manifest, 'disk_types')

          if cloud_config.nil? || cloud_config.empty?
            if manifest.has_key?('jobs')
              manifest['jobs'].each do |job|
                if job.has_key?('migrated_from')
                  raise Bosh::Director::DeploymentInvalidProperty,
                    "Deployment manifest instance groups contain 'migrated_from', but it can only be used with cloud-config enabled on your bosh director."
                end
              end
            end

            raise_if_has_key(manifest, 'stemcells')
          else
            deployment_cloud_properties = manifest.keys & CLOUD_MANIFEST_KEYS
            if deployment_cloud_properties.any?
              raise(
                Bosh::Director::DeploymentInvalidProperty,
                "Deployment manifest should not contain cloud config properties: #{deployment_cloud_properties}"
              )
            end
          end
        end

        private

        def raise_if_has_key(manifest, property)
          if manifest.has_key?(property)
            raise Bosh::Director::DeploymentInvalidProperty,
              "Deployment manifest contains '#{property}' section, but it can only be used with cloud-config enabled on your bosh director."
          end
        end
      end
    end
  end
end
