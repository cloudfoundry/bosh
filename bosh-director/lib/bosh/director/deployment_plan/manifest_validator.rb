module Bosh
  module Director
    class ManifestValidationError < RuntimeError; end

    module DeploymentPlan

      class ManifestValidator
        def validate!(deployment_manifest_hash)
          unless deployment_manifest_hash['name'].kind_of?(String)
            raise ManifestValidationError.new('name must be a string')
          end

          if deployment_manifest_hash['properties'] && !deployment_manifest_hash['properties'].kind_of?(Hash)
            raise ManifestValidationError.new('properties must be a hash')
          end

          if deployment_manifest_hash['releases']
            unless deployment_manifest_hash['releases'].kind_of?(Array)
              raise ManifestValidationError.new('releases must be an array')
            end

            seen_releases = {}
            deployment_manifest_hash['releases'].each_with_index do |release, idx|
              unless release['name'].kind_of?(String)
                raise ManifestValidationError.new("releases[#{idx}].name must be a string")
              end

              if seen_releases[release['name']]
                raise ManifestValidationError.new("release name '#{release['name']}' must be unique")
              end
              seen_releases[release['name']] = true
            end
          end
        end
      end
    end
  end
end


