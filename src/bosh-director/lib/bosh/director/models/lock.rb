module Bosh::Director::Models
  class Lock < Sequel::Model(Bosh::Director::Config.db)
    def validate
      validates_presence [:name,:expired_at, :uid]
      validates_unique [:name, :uid]
    end

  end
end
