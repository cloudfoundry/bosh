module Bosh::Director::Models
  class Vm < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance
    one_to_many :ip_addresses

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
      manual_or_vip_ips.concat(dynamic_ips).uniq
    end

    def manual_or_vip_ips
      ip_addresses.map { |ip| NetAddr::CIDR.create(ip.address).ip }
    end

    def dynamic_ips
      network_spec.map { |_, network| network['ip'] }
    end
  end
end
