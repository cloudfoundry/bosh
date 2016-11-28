# Copyright (c) 2009-2013 VMware, Inc.

module Bosh::Registry::Models
  class RegistryInstance < Sequel::Model

    def validate
      validates_presence [:instance_id, :settings]
      validates_unique :instance_id
    end

  end
end