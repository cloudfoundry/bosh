# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Models
  class Task < Sequel::Model(Bosh::Director::Config.db)
    many_to_one  :user
    def validate
      validates_presence [:state, :timestamp, :description]
    end
  end
end
