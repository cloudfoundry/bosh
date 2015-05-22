module Bosh::Director::DeploymentPlan
  class IpProviderFactory
    def initialize(deployment_model, options)
      @deployment_model = deployment_model
      @global_networking = options.fetch(:global_networking, false)
    end

    def create(range, network_name, restricted_ips, static_ips)
      if @global_networking
        DatabaseIpProvider.new(@deployment_model, range, network_name, restricted_ips, static_ips)
      else
        InMemoryIpProvider.new(range, network_name, restricted_ips, static_ips)
      end
    end
  end
end
