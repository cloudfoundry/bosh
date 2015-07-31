module Bosh::Director
  module DeploymentPlan
    class StateNetworkReservations
      def initialize(deployment)
        @deployment = deployment
      end

      def create_from_state(instance, state)
        reservations = {}
        state.fetch('networks', []).each do |name, network_config|
          network = @deployment.network(name)
          if network
            reservation = NetworkReservation.new_unresolved(instance, network_config['ip'])
            network.reserve(reservation)
            if reservation.reserved?
              reservations[network] = reservation
            end
          end
        end
        reservations
      end
    end
  end
end
