module Bosh::Director
  module DeploymentPlan
    class InstanceNetworkReservations
      include Enumerable
      include IpUtil

      def self.create_from_db(instance_model, deployment, logger)
        reservations = new(logger)
        reservations.logger.debug("Creating instance network reservations from database for instance '#{instance_model}'")

        orphaned_ip_addresses = Array(instance_model.ip_addresses_dataset.where(vm_id: nil, orphaned_vm_id: nil).all).clone
        ip_addresses = orphaned_ip_addresses + Array(instance_model.vms_dataset.order_by(:id).last&.ip_addresses).clone
        ip_addresses = instance_model.ip_addresses.clone if ip_addresses.empty?

        ip_addresses.each do |ip_address|
          reservations.add_existing(instance_model,
                                    deployment,
                                    ip_address.network_name,
                                    ip_address.formatted_ip,
                                    'not-dynamic')
        end

        unless instance_model.spec.nil?
          # Dynamic network reservations are not saved in DB, recreating from instance spec
          instance_model.spec.fetch('networks', []).each do |network_name, network_config|
            next unless network_config['type'] == 'dynamic'
            reservations.add_existing(instance_model, deployment, network_name, network_config['ip'], network_config['type'])
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

      def add_existing(instance_model, deployment, network_name, ip, existing_network_type)
        network = find_network(deployment, ip, network_name, instance_model) # TODO: IPv6 finding network ambiguous?
        reservation = ExistingNetworkReservation.new(instance_model, network, ip, existing_network_type)
        deployment.ip_provider.reserve_existing_ips(reservation)
        @reservations << reservation
      end

      private

      def find_network(deployment, ip, network_name, instance_model)
        cidr_ip =  NetAddr::CIDR.create(ip)
        networks = deployment.networks.dup

        network_match_on_name = deployment.network(network_name)

        if network_subnets_need_checking(network_match_on_name) # manual and global vip
          networks.unshift(networks.find { |network| network.name == network_name }).compact!

          networks.reject { |n| n.is_a? DynamicNetwork }.each do |network|
            ip_in_subnet = network.subnets.find { |snet| snet.is_reservable?(cidr_ip) }
            next unless ip_in_subnet

            @logger.debug("Registering existing reservation with IP '#{format_ip(cidr_ip)}' for instance '#{instance_model}'"\
              "on network '#{network.name}'")
            return network
          end
        elsif network_match_on_name # dynamic and static vip
          @logger.debug("Registering existing reservation with IP '#{format_ip(cidr_ip)}' for instance '#{instance_model}'"\
            "on network '#{network_name}'")
          return network_match_on_name
        end

        @logger.debug("Failed to find network #{network_name} or a network with valid subnets for #{format_ip(cidr_ip)},"\
          'reservation will be marked as obsolete')
        Network.new(network_name, nil)
      end

      def network_subnets_need_checking(network_match_on_name)
        network_match_on_name.nil? ||
          network_match_on_name.is_a?(ManualNetwork) ||
          (network_match_on_name.is_a?(VipNetwork) && network_match_on_name.globally_allocate_ip?)
      end
    end
  end
end
