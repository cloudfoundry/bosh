module Bosh::Director
  module DeploymentPlan
    class InstanceNetworkReservations
      include Enumerable
      include IpUtil

      def self.create_from_state(instance, state, deployment, logger)
        reservations = new(instance, logger)
        reservations.logger.debug("Creating instance network reservations from agent state for instance '#{instance}'")

        state.fetch('networks', []).each do |network_name, network_config|
          reservations.add_from_network(deployment, network_config['ip'], network_name)
        end

        reservations
      end

      def self.create_from_db(instance, deployment, logger)
        reservations = new(instance, logger)
        reservations.logger.debug("Creating instance network reservations from database for instance '#{instance}'")

        ip_addresses = instance.model.ip_addresses.clone

        ip_addresses.each do |ip_address|
          reservations.add_from_network(deployment, ip_address.address, ip_address.network_name)
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

      def add_from_network(deployment, ip, network_name)
        network = deployment.network(network_name) || deployment.default_network
        @logger.debug("Reserving ip '#{format_ip(ip)}' for existing instance '#{@instance}' for network '#{network.name}'")
        reservation = UnboundNetworkReservation.new(@instance, network, ip)
        reservation.reserve
        add(reservation)
      end

      def add(reservation)
        @logger.debug("Adding reservation '#{reservation}' for '#{reservation.instance}' for network '#{reservation.network.name}'")
        old_reservation = find_for_network(reservation.network)

        if old_reservation
          raise NetworkReservationAlreadyExists,
            "'#{reservation.instance}' already has reservation " +
              "for network '#{reservation.network.name}', IP #{old_reservation.ip}"
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
    end
  end
end
