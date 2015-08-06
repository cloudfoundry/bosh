module Bosh::Director
  module DeploymentPlan
    class InstanceNetworkReservations
      include Enumerable
      extend IpUtil

      def self.create_from_state(instance, state, deployment, logger)
        logger = TaggedLogger.new(logger, 'network-configuration')
        logger.debug("Creating instance network reservations from agent state for instance '#{instance}'")

        reservations = []
        state.fetch('networks', []).each do |network_name, network_config|
          network = deployment.network(network_name)
          if network
            logger.debug("Reserving ip '#{format_ip(network_config['ip'])}' for existing instance '#{instance}' for network '#{network.name}'")
            reservation = ExistingNetworkReservation.new(instance, network, network_config['ip'])
            reservation.reserve
            reservations << reservation
          end
        end

        new(reservations, logger)
      end

      def self.create_from_db(instance, deployment, logger)
        logger = TaggedLogger.new(logger, 'network-configuration')
        logger.debug("Creating instance network reservations from database for instance '#{instance}'")

        ip_addresses = instance.model.ip_addresses.clone

        reservations = []
        ip_addresses.each do |ip_address|
          network = deployment.network(ip_address.network_name)
          if network
            logger.debug("Reserving ip '#{format_ip(ip_address.address)}' for existing instance '#{instance} for network '#{network.name}'")
            reservation = ExistingNetworkReservation.new(instance, network, ip_address.address)
            reservation.reserve
            reservations << reservation
          end
        end

        new(reservations, logger)
      end

      def initialize(reservations, logger)
        @reservations = reservations
        @logger = logger
      end

      def find_for_network(network)
        @reservations.find { |r| r.network == network }
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
    end
  end
end
