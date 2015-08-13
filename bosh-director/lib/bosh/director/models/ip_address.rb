module Bosh::Director::Models
  class IpAddress < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance

    def validate
      validates_presence :instance_id
      validates_presence :task_id
      validates_presence :address
      validates_unique [:address, :network_name]
    end

    def before_create
      self.created_at ||= Time.now
    end

    def info
      "#{self.instance.deployment.name}.#{self.instance.job}/#{self.instance.index} - #{self.network_name} - #{NetAddr::CIDR.create(self.address).ip}"
    end
  end
end
