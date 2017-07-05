module Bosh::Director::Models
  class IpAddress < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance

    def validate
      validates_presence :instance_id
      validates_presence :task_id
      validates_presence :address_str
      validates_unique :address_str
      raise "Invalid type for address_str column" unless address_str.is_a?(String)
    end

    def before_create
      self.created_at ||= Time.now
    end

    def info
      instance_info = "#{self.instance.deployment.name}.#{self.instance.job}/#{self.instance.index}"
      formatted_ip = NetAddr::CIDR.create(address_str.to_i).ip
      "#{instance_info} - #{self.network_name} - #{formatted_ip} (#{type})"
    end

    def type
      self.static ? 'static' : 'dynamic'
    end

    def to_s
      info
    end

    def address
      unless address_str.to_s =~ /\A\d+\z/
        raise "Unexpected address '#{address_str}' (#{info rescue "missing info"})"
      end
      address_str.to_i
    end
  end
end
