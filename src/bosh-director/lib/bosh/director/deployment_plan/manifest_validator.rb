module Bosh
  module Director
    module DeploymentPlan
      class ManifestValidator
        def validate(manifest)
          raise_if_has_key(manifest, 'vm_types')
          raise_if_has_key(manifest, 'azs')
          raise_if_has_key(manifest, 'disk_types')
          raise_if_has_key(manifest, 'compilation')

          if manifest.key?('networks')
            raise Bosh::Director::V1DeprecatedNetworks,
                  "Deployment 'networks' are no longer supported. Network definitions must now be provided in a cloud-config."
          end
        end

        private

        def raise_if_has_key(manifest, property)
          if manifest.key?(property)
            raise Bosh::Director::DeploymentInvalidProperty,
                  "Deployment manifest contains '#{property}' section, but this can only be set in a cloud-config."
          end
        end
      end
    end
  end
end
