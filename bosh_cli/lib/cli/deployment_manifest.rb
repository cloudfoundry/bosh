require 'common/deep_copy'

module Bosh::Cli
  class DeploymentManifest
    def initialize(manifest_hash)
      @manifest_hash = manifest_hash
    end

    def normalize
      normalized = Bosh::Common::DeepCopy.copy(manifest_hash)

      %w(releases networks jobs resource_pools disk_pools).each do |section|
        normalized[section] ||= []

        unless normalized[section].kind_of?(Array)
          manifest_error("#{section} is expected to be an array")
        end

        normalized[section] = normalized[section].inject({}) do |acc, e|
          if e["name"].blank?
            manifest_error("missing name for one of entries in '#{section}'")
          end
          if acc.has_key?(e["name"])
            manifest_error("duplicate entry '#{e['name']}' in '#{section}'")
          end
          acc[e["name"]] = e
          acc
        end
      end

      normalized["networks"].each do |network_name, network|
        # VIP and dynamic networks do not require subnet,
        # but if it's there we can run some sanity checks
        next unless network.has_key?("subnets")

        unless network["subnets"].kind_of?(Array)
          manifest_error("network subnets is expected to be an array")
        end

        subnets = network["subnets"].inject({}) do |acc, e|
          if e["range"].blank?
            manifest_error("missing range for one of subnets " +
                             "in '#{network_name}'")
          end
          if acc.has_key?(e["range"])
            manifest_error("duplicate network range '#{e['range']}' " +
                             "in '#{network}'")
          end
          acc[e["range"]] = e
          acc
        end

        normalized["networks"][network_name]["subnets"] = subnets
      end

      normalized
    end

    private
    attr_reader :manifest_hash

    def manifest_error(err)
      err("Deployment manifest error: #{err}")
    end
  end
end
