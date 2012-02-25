module Bosh::Deployer::Models
  class Instance < Sequel::Model(Bosh::Deployer::Config.db[:instances])
  end
end
