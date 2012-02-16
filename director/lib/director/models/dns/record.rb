# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Models::Dns
  class Record < Sequel::Model(Bosh::Director::Config.dns_db)
    many_to_one :domain
  end
end
