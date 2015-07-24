module Bosh::Director::Models
  class IpAddress < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment

    def validate
      validates_presence :deployment_id
      validates_presence :task_id
    end

    def before_create
      self.created_at ||= Time.now
    end
  end
end
