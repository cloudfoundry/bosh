module Bosh::Director::Models
  class Tag < Sequel::Model(Bosh::Director::Config.db)
    many_to_many :deployments

    def validate
      validates_presence [:key, :value]
      validates_unique [:key, :value]
    end

    def desc
      "#{key}/#{value}"
    end
  end
end
