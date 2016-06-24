module Bosh::Director
  module LegacyDeploymentHelper
    def ignore_cloud_config?(manifest_hash)
      manifest_hash.has_key?('networks')
    end
  end
end
