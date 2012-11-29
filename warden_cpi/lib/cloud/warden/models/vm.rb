module Bosh::WardenCloud::Models
  class VM < Sequel::Model(Bosh::Clouds::Config.db[:warden_vm])
    one_to_many :disks, :key => :vm_id
  end
end
