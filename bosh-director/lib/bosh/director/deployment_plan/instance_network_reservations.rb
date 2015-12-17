module Bosh::Director
  module DeploymentPlan
    class InstanceNetworkReservations
      include Enumerable
      include IpUtil

      def self.create_from_state(instance, state, deployment, logger)
        reservations = new(logger)
        reservations.logger.debug("Creating instance network reservations from agent state for instance '#{instance}'")

        state.fetch('networks', []).each do |network_name, network_config|
          reservations.add_existing(instance, deployment, network_name,  network_config['ip'], '', network_config['type'])
        end

        reservations
      end

      def self.create_from_db(instance, deployment, logger)
        reservations = new(logger)
        reservations.logger.debug("Creating instance network reservations from database for instance '#{instance}'")

        ip_addresses = instance.model.ip_addresses.clone

        ip_addresses.each do |ip_address|
          reservations.add_existing(instance, deployment, ip_address.network_name, ip_address.address, ip_address.type, 'manual')
        end

        unless instance.model.spec.nil?
          # Dynamic network reservations are not saved in DB, recreating from instance spec
          instance.model.spec.fetch('networks', []).each do |network_name, network_config|
            next unless network_config['type'] == 'dynamic'
            reservations.add_existing(instance, deployment, network_name, network_config['ip'], '', network_config['type'])
          end
        end

        reservations
      end

      def initialize(logger)
        @reservations = []
        @logger = TaggedLogger.new(logger, 'network-configuration')
      end

      attr_reader :logger

      def find_for_network(network)
        @reservations.find { |r| r.network == network }
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

      def add_existing(instance, deployment, network_name, ip, ip_type, existing_network_type)
        network = deployment.network(network_name) || deployment.deleted_network(network_name)
        @logger.debug("Registering existing reservation with #{ip_type} IP '#{format_ip(ip)}' for instance '#{instance}' on network '#{network.name}'")
        reservation = ExistingNetworkReservation.new(instance, network, ip, existing_network_type)
        deployment.ip_provider.reserve_existing_ips(reservation)
        @reservations << reservation
      end
    end
  end
end
