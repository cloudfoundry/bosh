module Bosh::Director::Models
  class LocalDnsRecord  < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance

    def self.insert_tombstone
      create(:ip => "#{SecureRandom.uuid}-tombstone")
    end
  end
end
