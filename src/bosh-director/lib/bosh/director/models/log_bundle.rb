module Bosh::Director::Models
  class LogBundle < Sequel::Model(Bosh::Director::Config.db)
    def validate
      validates_presence [:blobstore_id, :timestamp ]
      validates_unique [ :blobstore_id ]
    end
  end
end
