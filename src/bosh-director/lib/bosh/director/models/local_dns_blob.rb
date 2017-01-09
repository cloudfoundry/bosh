module Bosh::Director::Models
  class LocalDnsBlob < Sequel::Model(Bosh::Director::Config.db)

    def self.latest
      Bosh::Director::Config.db.transaction(:isolation => :committed, :retry_on => [Sequel::SerializationFailure]) do
        LocalDnsBlob.where(id: LocalDnsBlob.max(:id)).first
      end
    end
  end
end
