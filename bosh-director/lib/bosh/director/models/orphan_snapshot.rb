module Bosh::Director::Models
  class OrphanSnapshot < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :orphan_disk

    def validate
      validates_presence [:snapshot_cid, :snapshot_created_at]
      validates_unique [:snapshot_cid]
    end

    def before_create
      self.created_at ||= Time.now
    end
  end
end
