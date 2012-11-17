module Bosh::WardenCloud::Models
  class VM < Sequel::Model(Bosh::Clouds::Config.db[:warden_vm])
  end
end
