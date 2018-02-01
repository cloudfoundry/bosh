module Bosh::Director::Models
  class StemcellUpload < Sequel::Model(Bosh::Director::Config.db)
    def validate
      validates_presence %i[name version]
      validates_unique %i[name version cpi]
    end

    def desc
      "#{name}/#{version}"
    end
  end
end
