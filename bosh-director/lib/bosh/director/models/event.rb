# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Models
  class Event < Sequel::Model(Bosh::Director::Config.db)
    def validate
      validates_presence [:target_type, :event_action, :event_state, :event_state, :task_id, :timestamp]
    end
  end
end
