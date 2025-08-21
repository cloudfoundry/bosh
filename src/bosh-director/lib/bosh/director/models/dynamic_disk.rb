module Bosh::Director::Models
  class DynamicDisk < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment
    many_to_one :vm

    def validate
      validates_presence [:name, :disk_cid]
      validates_unique [:name, :disk_cid]
    end

    def metadata
      result = self.metadata_json
      result ? JSON.parse(result) : {}
    end

    def metadata=(metadata)
      self.metadata_json = JSON.generate(metadata)
    end

    def to_s
      "#{self.name}/#{self.disk_cid}"
    end
  end
end
