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
      ips_cidr.map do | cidr_ip |
       if ( cidr_ip.include?(':') && cidr_ip.include?('/128') ) || ( cidr_ip.include?('.')  && cidr_ip.include?('/32') )
        cidr_ip.split('/')[0]
       else
        cidr_ip
       end
      end
    end

    def ips_cidr
      manual_or_vip_ips.concat(dynamic_ips).uniq
    end

    private

    def manual_or_vip_ips
      ip_addresses.map(&:formatted_ip)
    end

    def dynamic_ips
      network_spec.map do |_, network|
        prefix = network['prefix'].to_s
        if network['ip'].include?(':') && prefix.empty?
          prefix = '128'
        elsif network['ip'].include?('.') && prefix.empty?
          prefix = '32'
        end
        "#{network['ip']}/#{prefix}"
      end
    end
  end
end
