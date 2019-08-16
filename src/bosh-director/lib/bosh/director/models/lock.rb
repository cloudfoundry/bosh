module Bosh::Director::Models
  class Lock < Sequel::Model(Bosh::Director::Config.db)
    def validate
      validates_presence %i[name expired_at uid]
      validates_unique %i[name uid]
    end
  end
end
