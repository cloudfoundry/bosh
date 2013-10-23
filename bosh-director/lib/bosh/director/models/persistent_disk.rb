# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Models
  class PersistentDisk < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance
    one_to_many :snapshots

    def validate
      validates_presence [:instance_id, :disk_cid]
      validates_unique [:disk_cid]
    end
  end
end
