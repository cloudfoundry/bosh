module Bosh::Director::Models
  class IpAddress < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance

    def validate
      validates_presence :instance_id
      validates_presence :task_id
      validates_presence :address
      validates_unique :address
    end

    def before_create
      self.created_at ||= Time.now
    end

    def info
      instance_info = "#{self.instance.deployment.name}.#{self.instance.job}/#{self.instance.index}"
      "#{instance_info} - #{self.network_name} - #{formatted_ip} (#{type})"
    end

    def formatted_ip
      NetAddr::CIDR.create(self.address).ip
    end

    def type
      self.static ? 'static' : 'dynamic'
    end

    def to_s
      info
    end
  end
end
