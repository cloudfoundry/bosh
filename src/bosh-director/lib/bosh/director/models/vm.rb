module Bosh::Director::Models
  class Vm < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance
    one_to_many :ip_addresses
    one_to_many :dynamic_disks

    def before_destroy
      ip_addresses_dataset.each do |ip_address|
        remove_ip_address(ip_address)
      end
    end

    def network_spec
      JSON.parse(network_spec_json || '{}')
    end

    def network_spec=(spec)
      spec ||= {}
      self.network_spec_json = JSON.dump(spec)
    end

    def ips
      ips_cidr.map do |cidr_ip|
        if ( cidr_ip.include?(':') && cidr_ip.include?("/#{Bosh::Director::DeploymentPlan::Network::IPV6_DEFAULT_PREFIX_SIZE}") ) || ( cidr_ip.include?('.')  && cidr_ip.include?("/#{Bosh::Director::DeploymentPlan::Network::IPV4_DEFAULT_PREFIX_SIZE}") )
          cidr_ip.split('/')[0]
        else
          cidr_ip
        end
      end.uniq.sort_by { |ip| Bosh::Director::IpAddrOrCidr.new(ip).to_i }
    end

    def ips_cidr
      manual_or_vip_ips.concat(dynamic_ips)
    end

    private

    def manual_or_vip_ips
      ip_addresses.map(&:formatted_ip_without_prefix_for_single_ips)
    end

    def dynamic_ips
      network_spec.map do |_, network|
        network['prefix'].nil? || network['prefix'].empty? ? network['ip'] : "#{network['ip']}/#{network['prefix']}"
      end
    end
  end
end
