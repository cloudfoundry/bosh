module Bosh::Director::Models
  class Vm < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance
  end

  def before_create
    self.created_at ||= Time.now
  end
end
