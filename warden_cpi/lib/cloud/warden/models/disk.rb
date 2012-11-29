module Bosh::WardenCloud::Models
  class Disk < Sequel::Model(Bosh::Clouds::Config.db[:warden_disk])
    many_to_one :vm, :key => :vm_id, :class => Bosh::WardenCloud::Models::VM
  end
end
