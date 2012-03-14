# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsRegistry::Models
  class AwsInstance < Sequel::Model

    def validate
      validates_presence [:instance_id, :settings]
      validates_unique :instance_id
    end

  end
end

