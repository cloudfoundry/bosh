module Bosh::Director::Models
  class PersistentDisk < Sequel::Model
    many_to_one :instance

    def validate
      validates_presence [:instance_id, :disk_cid]
      validates_unique [:disk_cid]
    end
  end
end
