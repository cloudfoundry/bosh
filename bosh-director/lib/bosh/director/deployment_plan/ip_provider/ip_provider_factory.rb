module Bosh::Director::DeploymentPlan
  class NullIpProviderFactory
    def create(*args)
      nil
    end
  end

  class IpProviderFactory
    def initialize(logger, options)
      @global_networking = options.fetch(:global_networking, false)
      @logger = logger
    end

    def create(range, network_name, restricted_ips, static_ips)
      if @global_networking
        DatabaseIpProvider.new(range, network_name, restricted_ips, static_ips, @logger)
      else
        nil # if you try and call this it's wrong
      end
    end
  end
end
