module Bosh::Director::DeploymentPlan
  class IpProviderFactory
    def initialize(options)
      @shared_network = options.fetch(:cloud_config, false)
    end

    def create(range, network_name, restricted_ips, static_ips)
      if @shared_network
        DatabaseIpProvider.new(range, network_name, restricted_ips, static_ips)
      else
        InMemoryIpProvider.new(range, network_name, restricted_ips, static_ips)
      end
    end
  end
end
