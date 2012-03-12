# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Deployer::Models
  class Instance < Sequel::Model(Bosh::Deployer::Config.db[:instances])
  end
end
