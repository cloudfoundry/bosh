module Bosh::Director
  class DeploymentPlan::NetworkSettings
    def initialize(instance_group_name, deployment_name, default_network, desired_reservations, current_networks, availability_zone, instance_index, instance_id, root_domain, use_short_dns_addresses)
      @instance_group_name = instance_group_name
      @desired_reservations = desired_reservations
      @default_network = default_network
      @deployment_name = deployment_name
      @availability_zone = availability_zone
      @instance_index = instance_index
      @instance_id = instance_id
      @current_networks = current_networks
      @root_domain = root_domain
      @dns_encoder = LocalDnsEncoderManager.create_dns_encoder(use_short_dns_addresses)
    end

    def to_hash
      default_properties = {}
      @default_network.each do |key, value|
        (default_properties[value] ||= []) << key
      end

      network_settings = {}
      @desired_reservations.each do |reservation|
        network_name = reservation.network.name
        network_settings[network_name] = reservation.network.network_settings(reservation, default_properties[network_name], @availability_zone)
        # Somewhat of a hack: for dynamic networks we might know IP address, Netmask & Gateway
        # if they're featured in agent state, in that case we put them into network spec to satisfy
        # ConfigurationHasher in both agent and director.
        if @current_networks.is_a?(Hash) && @current_networks[network_name].is_a?(Hash) && network_settings[network_name]['type'] == 'dynamic'
          %w(ip netmask gateway).each do |key|
            network_settings[network_name][key] = @current_networks[network_name][key] unless @current_networks[network_name][key].nil?
          end
        end
      end

      network_settings
    end

    def dns_record_info
      dns_record_info = {}
      to_hash.each do |network_name, network|
        index_dns_name = DnsNameGenerator.dns_record_name(@instance_index, @instance_group_name, network_name, @deployment_name, @root_domain)
        dns_record_info[index_dns_name] = network['ip']
        id_dns_name =  DnsNameGenerator.dns_record_name(@instance_id, @instance_group_name, network_name, @deployment_name, @root_domain)
        dns_record_info[id_dns_name] = network['ip']
      end
      dns_record_info
    end

    def network_address(prefer_dns_entry)
      network_name = @default_network['addressable'] || @default_network['gateway']
      get_address(network_name, to_hash[network_name], prefer_dns_entry)
    end

    # @param [Boolean] prefer_dns_entry Flag for using DNS entry when available.
    # @return [Hash] A hash mapping network names to their associated address
    def network_addresses(prefer_dns_entry)
      network_addresses = {}

      to_hash.each do |network_name, network|
        network_addresses[network_name] = get_address(network_name, network, prefer_dns_entry)
      end

      network_addresses
    end

    private

    def get_address(network_name, network, prefer_dns_entry = true)
      if should_use_dns?(network, prefer_dns_entry)
        return @dns_encoder.encode_query({
          root_domain: @root_domain,
          default_network: network_name,
          deployment_name: @deployment_name,
          uuid: @instance_id,
          instance_group: @instance_group_name,
        })
      else
        return network['ip']
      end
    end

    def should_use_dns?(network, prefer_dns_entry)
      network['type'] == 'dynamic' || (prefer_dns_entry && Bosh::Director::Config.local_dns_enabled?)
    end
  end
end
