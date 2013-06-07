module Bosh::Director::Models
  class DirectorAttribute < Sequel::Model(Bosh::Director::Config.db)

    def validate
      validates_unique [:uuid]
    end

  end
end
