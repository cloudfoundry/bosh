module Bosh::Director::Models
  class IpAddress < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance
    many_to_one :vm
    many_to_one :orphaned_vm

    def validate
      raise 'No instance or orphaned VM associated with IP' if instance_id.nil? && orphaned_vm_id.nil?
      raise 'IP address cannot have both instance id and orphaned VM id' if !instance_id.nil? && !orphaned_vm_id.nil?
      validates_presence :instance_id, allow_nil: true
      validates_presence :orphaned_vm_id, allow_nil: true
      validates_presence :task_id
      validates_presence :address_str
      validates_unique :address_str
      raise 'Invalid type for address_str column' unless address_str.is_a?(String)
    end

    def before_create
      self.created_at ||= Time.now
    end

    def info
      [
        "#{instance.deployment.name}.#{instance.job}/#{instance.index}",
        network_name,
        "#{Bosh::Director::IpAddrOrCidr.new(address_str)} (#{type})"
      ].join(' - ')
    end

    def formatted_ip
      Bosh::Director::IpAddrOrCidr.new(address).to_s
    end

    def type
      static ? 'static' : 'dynamic'
    end

    def address_int_and_prefix
      address_and_prefix = address.split('/')
      [Bosh::Director::IpAddrOrCidr.new(address_and_prefix[0]).to_i, address_and_prefix[1]]
    end

    def address
      if address_str.include?('/')
        return Bosh::Director::IpAddrOrCidr.new(address_str)
      else
        ip = Bosh::Director::IpAddrOrCidr.new(address_str.to_i)
        if ip.ipv6?
          prefix = 132
        else
          prefix = 32
        end
        address_str = Bosh::Director::IpAddrOrCidr.new("#{ip}/#{prefix}")
        return address_str
      end
    end

    def to_s
      info
    end
  end
end
