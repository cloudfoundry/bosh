module Bosh::Director::Models
  class PersistentDisk < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance
    one_to_many :snapshots

    def validate
      validates_presence [:instance_id, :disk_cid]
      validates_unique [:disk_cid]
    end

    def cloud_properties
      result = self.cloud_properties_json
      result ? JSON.parse(result) : {}
    end

    def cloud_properties=(cloud_properties)
      self.cloud_properties_json = JSON.generate(cloud_properties)
    end

    def managed?
      name == ''
    end

    def cpi
      super || instance.cpi
    end

    def to_s
      "#{self.name}/#{self.disk_cid}"
    end
  end
end
