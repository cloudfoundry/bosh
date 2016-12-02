module Bosh::Director::Models
  class OrphanDisk < Sequel::Model(Bosh::Director::Config.db)
    one_to_many :orphan_snapshots

    def validate
      validates_presence [:disk_cid, :deployment_name, :instance_name]
      validates_unique [:disk_cid]
    end

    def before_create
      self.created_at ||= Time.now
    end

    def cloud_properties
      result = self.cloud_properties_json
      result ? JSON.parse(result) : {}
    end

    def cloud_properties=(cloud_properties)
      self.cloud_properties_json = JSON.generate(cloud_properties)
    end
  end
end
