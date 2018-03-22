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
  end
end
