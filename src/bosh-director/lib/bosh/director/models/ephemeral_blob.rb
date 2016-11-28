module Bosh::Director::Models
  class EphemeralBlob < Sequel::Model(Bosh::Director::Config.db)
    def before_validation
      self.created_at ||= Time.now
    end
    def validate
      validates_presence [:blobstore_id, :sha1, :created_at ]
      validates_unique [ :blobstore_id ]
    end
  end
end