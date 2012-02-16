# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Models
  class User < Sequel::Model(Bosh::Director::Config.db)
    def validate
      validates_presence :username
      validates_presence :password
      validates_unique :username
    end
  end
end
