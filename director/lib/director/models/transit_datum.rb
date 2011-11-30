module Bosh::Director::Models
  class TransitDatum < Sequel::Model
    def validate
      validates_presence [:blobstore_id, :timestamp, :tag ]
      validates_unique [ :blobstore_id ]
    end
  end
end
