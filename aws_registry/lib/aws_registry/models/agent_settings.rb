# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AWSRegistry::Models
  class AgentSettings < Sequel::Model

    def validate
      validates_presence [:ip_address, :settings]
      validates_unique :ip_address
    end

  end
end

