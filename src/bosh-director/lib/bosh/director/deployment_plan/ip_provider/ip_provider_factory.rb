module Bosh::Director
  module DeploymentPlan
    class IpProviderFactory
      def initialize(logger)
        @logger = logger
      end

      def new_ip_provider(networks)
        ip_repo = DatabaseIpRepo.new(@logger)
        IpProvider.new(ip_repo, networks, @logger)
      end
    end
  end
end
