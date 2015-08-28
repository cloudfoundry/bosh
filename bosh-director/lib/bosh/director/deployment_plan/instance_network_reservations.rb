module Bosh::Director
  module DeploymentPlan
    class InstanceNetworkReservations
      include Enumerable
      include IpUtil

      def self.create_from_state(instance, state, deployment, logger)
        reservations = new(instance, logger)
        reservations.logger.debug("Creating instance network reservations from agent state for instance '#{instance}'")

        state.fetch('networks', []).each do |network_name, network_config|
          reservations.add_existing(deployment, network_name,  network_config['ip'], '')
        end

        reservations
      end

      def self.create_from_db(instance, deployment, logger)
        reservations = new(instance, logger)
        reservations.logger.debug("Creating instance network reservations from database for instance '#{instance}'")

        ip_addresses = instance.model.ip_addresses.clone

        ip_addresses.each do |ip_address|
          reservations.add_existing(deployment, ip_address.network_name, ip_address.address, ip_address.type)
        end

        reservations
      end

      def initialize(instance, logger)
        @instance = instance
        @reservations = []
        @logger = TaggedLogger.new(logger, 'network-configuration')
      end

      attr_reader :logger

      def find_for_network(network)
        @reservations.find { |r| r.network == network }
      end

      def add(reservation)
        @logger.debug("Requesting #{reservation.desc} for '#{reservation.instance}' on network '#{reservation.network.name}' based on deployment manifest")
        old_reservation = find_for_network(reservation.network)

        if old_reservation
          raise NetworkReservationAlreadyExists,
            "Failed to add #{reservation.desc} for instance '#{reservation.instance}' on network '#{reservation.network.name}', " +
              "instance already has #{old_reservation.desc} on the same network"
        end

        @reservations << reservation
      end

      def clean
        @reservations = []
      end

      def each(&block)
        @reservations.each(&block)
      end

      def delete(reservation)
        @reservations.delete(reservation)
      end

      def add_existing(deployment, network_name, ip, ip_type)
        network = deployment.network(network_name) || deployment.default_network
        @logger.debug("Registering existing reservation with #{ip_type} IP '#{format_ip(ip)}' for instance '#{@instance}' on network '#{network.name}'")
        ip_provider = IpProviderV2.new(IpRepoThatDelegatesToExistingStuff.new)
        reservation = ExistingNetworkReservation.new(@instance, network, ip)
        ip_provider.reserve(reservation)
        @reservations << reservation
      end
    end
  end
end
