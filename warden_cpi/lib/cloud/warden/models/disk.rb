module Bosh::WardenCloud::Models
  class Disk < Sequel::Model(Bosh::Clouds::Config.db[:warden_disk])
  end
end
