module Bosh::Director::Models
  class Snapshot < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :persistent_disk

    def validate
      validates_unique [:snapshot_cid]
    end

    def before_create
      self.created_at ||= Time.now
    end
  end
end
