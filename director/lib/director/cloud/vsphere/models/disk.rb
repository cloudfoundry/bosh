module VSphereCloud::Models
  class Disk < Sequel::Model(Bosh::Director::Config.db[:vsphere_disk])
    def validate
      validates_presence :size
      validates_integer :size
    end
  end
end
