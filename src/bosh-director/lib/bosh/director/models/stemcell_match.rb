module Bosh::Director::Models
  class StemcellMatch < Sequel::Model(Bosh::Director::Config.db)
    def validate
      validates_presence [:name, :version]
      validates_unique [:name, :version, :cpi]
    end

    def desc
      "#{name}/#{version}"
    end
  end
end
