module Bosh::WardenCloud::Models
  class DiskModel < Sequel::Model(Bosh::Clouds::Config.db[:warden_disk])
    def validate
#      validates_presence :size
#      validates_integer :size
    end
  end
end
