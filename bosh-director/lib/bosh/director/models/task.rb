# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Models
  class Task < Sequel::Model(Bosh::Director::Config.db)
    def validate
      validates_presence [:state, :timestamp, :description]
    end
  end
end
