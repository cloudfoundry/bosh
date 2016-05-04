module Bosh::Director
  module LegacyDeploymentHelper
    def ignore_cloud_config?(manifest_text)
      manifest_text.has_key?('networks')
    end
  end
end
