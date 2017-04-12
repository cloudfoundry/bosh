module Bosh::Director
  class DeploymentPlan::NetworkSettings
    def initialize(job_name, deployment_name, default_network, desired_reservations, current_networks, availability_zone, instance_index, instance_id, root_domain)
      @job_name = job_name
      @desired_reservations = desired_reservations
      @default_network = default_network
      @deployment_name = deployment_name
      @availability_zone = availability_zone
      @instance_index = instance_index
      @instance_id = instance_id
      @current_networks = current_networks
      @root_domain = root_domain
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
        index_dns_name = DnsNameGenerator.dns_record_name(@instance_index, @job_name, network_name, @deployment_name, @root_domain)
        dns_record_info[index_dns_name] = network['ip']
        id_dns_name =  DnsNameGenerator.dns_record_name(@instance_id, @job_name, network_name, @deployment_name, @root_domain)
        dns_record_info[id_dns_name] = network['ip']
      end
      dns_record_info
    end

    def network_address(preferred_network_name = nil)
      network_name = preferred_network_name || @default_network['gateway']
      network_hash = to_hash
      if network_hash[network_name]['type'] == 'dynamic' || Bosh::Director::Config.local_dns_enabled?
        address = DnsNameGenerator.dns_record_name(@instance_id, @job_name, network_name, @deployment_name, @root_domain)
      else
        address = network_hash[network_name]['ip']
      end

      address
    end

    def network_ip_address(preferred_network_name = nil)
      network_name = preferred_network_name || @default_network['addressable'] || @default_network['gateway']
      to_hash[network_name]['ip']
    end

    def network_addresses
      network_addresses = {}

      to_hash.each do |network_name, network|
        if network['type'] == 'dynamic'
          address = DnsNameGenerator.dns_record_name(@instance_id, @job_name, network_name, @deployment_name, @root_domain)
        else
          address = network['ip']
        end

        network_addresses[network_name] = address
      end

      network_addresses
    end

  end
end
