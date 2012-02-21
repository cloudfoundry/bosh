# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Models::Dns
  class Domain < Sequel::Model(Bosh::Director::Config.dns_db)
    one_to_many :records
  end
end
