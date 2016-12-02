module Bosh::Director
  module DeploymentPlan
    class IpProviderFactory
      def initialize(using_global_networking, logger)
        @using_global_networking = using_global_networking
        @logger = logger
      end

      def new_ip_provider(networks)
        if @using_global_networking
          @logger.debug('Using database ip repo')
          ip_repo = DatabaseIpRepo.new(@logger)
        else
          @logger.debug('Using in-memory ip repo')
          ip_repo = InMemoryIpRepo.new(@logger)
        end

        IpProvider.new(ip_repo, networks, @logger)
      end
    end
  end
end
