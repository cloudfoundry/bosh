module Bosh::Director::DeploymentPlan
  class NetworkSettings
    def initialize(job_name, deployment_name, default_network, desired_reservations, state, availability_zone, instance_index, instance_id, dns_manager)
      @job_name = job_name
      @desired_reservations = desired_reservations
      @default_network = default_network
      @deployment_name = deployment_name
      @state = state
      @availability_zone = availability_zone
      @instance_index = instance_index
      @instance_id = instance_id
      @dns_manager = dns_manager
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
        if @state.is_a?(Hash) &&
          @state['networks'].is_a?(Hash) &&
          @state['networks'][network_name].is_a?(Hash) &&
          network_settings[network_name]['type'] == 'dynamic'
          %w(ip netmask gateway).each do |key|
            network_settings[network_name][key] = @state['networks'][network_name][key]
          end
        end
      end

      network_settings
    end

    def dns_record_info
      dns_record_info = {}
      to_hash.each do |network_name, network|
        index_dns_name =  @dns_manager.dns_record_name(@instance_index, @job_name, network_name, @deployment_name)
        dns_record_info[index_dns_name] = network['ip']
        id_dns_name =  @dns_manager.dns_record_name(@instance_id, @job_name, network_name, @deployment_name)
        dns_record_info[id_dns_name] = network['ip']
      end
      dns_record_info
    end

    def network_addresses
      network_addresses = {}
      to_hash.each do |network_name, network|
        network_addresses[network_name] = {
          'address' => network['type'] == 'dynamic' ?
            @dns_manager.dns_record_name(@instance_id, @job_name, network_name, @deployment_name) :
            network['ip']
        }
      end
      network_addresses
    end
  end
end
