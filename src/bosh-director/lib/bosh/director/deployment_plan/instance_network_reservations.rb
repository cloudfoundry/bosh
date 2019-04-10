module Bosh::Director
  module DeploymentPlan
    class InstanceNetworkReservations
      include Enumerable
      include IpUtil

      def self.create_from_state(instance_model, state, deployment, logger)
        reservations = new(logger)
        reservations.logger.debug("Creating instance network reservations from agent state for instance '#{instance_model}'")

        state.fetch('networks', []).each do |network_name, network_config|
          reservations.add_existing(instance_model, deployment, network_name, network_config['ip'], '', network_config['type'])
        end

        reservations
      end

      def self.create_from_db(instance_model, deployment, logger)
        reservations = new(logger)
        reservations.logger.debug("Creating instance network reservations from database for instance '#{instance_model}'")

        ip_addresses = Array(instance_model.vms_dataset.order_by(:id).last&.ip_addresses).clone
        ip_addresses = instance_model.ip_addresses.clone if ip_addresses.empty?

        ip_addresses.each do |ip_address|
          reservations.add_existing(instance_model,
                                    deployment,
                                    ip_address.network_name,
                                    ip_address.address,
                                    ip_address.type,
                                    'not-dynamic')
        end

        unless instance_model.spec.nil?
          # Dynamic network reservations are not saved in DB, recreating from instance spec
          instance_model.spec.fetch('networks', []).each do |network_name, network_config|
            next unless network_config['type'] == 'dynamic'
            reservations.add_existing(instance_model, deployment, network_name, network_config['ip'], '', network_config['type'])
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

      def add_existing(instance_model, deployment, network_name, ip, ip_type, existing_network_type)
        network = guess_network_from_cloud_config(deployment, ip, network_name)
        @logger.debug("Registering existing reservation with #{ip_type} IP '#{format_ip(ip)}' for instance '#{instance_model}' on network '#{network.name}'")
        reservation = ExistingNetworkReservation.new(instance_model, network, ip, existing_network_type)
        deployment.ip_provider.reserve_existing_ips(reservation)
        @reservations << reservation
      end

      private

      def guess_network_from_cloud_config(deployment, cidr_ip, network_name)
        networks = deployment.networks.dup

        network_match_on_name = deployment.network(network_name)

        if networks_that_need_valid_subnets(network_match_on_name) # manual and global vip
          networks.unshift(networks.find { |network| network.name == network_name }).compact!

          networks.reject { |n| n.is_a? DynamicNetwork }.each do |network|
            subnet = network.subnets.find { |snet| snet.is_reservable?(cidr_ip) }
            return network if subnet
          end
        elsif network_match_on_name # dynamic and static vip
          return network_match_on_name
        end

        Network.new(network_name, nil)
      end

      def networks_that_need_valid_subnets(network_match_on_name)
        network_match_on_name.nil? ||
          network_match_on_name.is_a?(ManualNetwork) ||
          (network_match_on_name.is_a?(VipNetwork) && network_match_on_name.globally_allocate_ip?)
      end
    end
  end
end
