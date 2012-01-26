module VSphereCloud::Models
  class Disk < Sequel::Model(:vsphere_disk)
    def validate
      validates_presence :size
      validates_integer :size
    end
  end
end
