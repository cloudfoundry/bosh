module Bosh::Director::DeploymentPlan
  class NetworkReservationRepository
    def initialize(deployment_plan, logger)
      @deployment_plan = deployment_plan
      @logger = logger
    end

    def fetch_network_reservations(existing_instance_model, existing_instance_state)
      if existing_instance_model.ip_addresses.any?
        InstanceNetworkReservations.create_from_db(existing_instance_model, @deployment_plan, @logger)
      elsif existing_instance_state
        # This is for backwards compatibility when we did not store
        # network reservations in DB and constructed them from instance state
        InstanceNetworkReservations.create_from_state(existing_instance_model, existing_instance_state, @deployment_plan, @logger)
      else
        InstanceNetworkReservations.new(@logger)
      end
    end
  end
end
