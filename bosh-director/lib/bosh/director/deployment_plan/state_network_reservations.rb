module Bosh::Director
  module DeploymentPlan
    class StateNetworkReservations
      def initialize(deployment)
        @deployment = deployment
      end

      def create_from_state(state)
        reservations = {}
        state.fetch('networks', []).each do |name, network_config|
          network = @deployment.network(name)
          if network
            reservation = NetworkReservation.new(:ip => network_config['ip'])
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
