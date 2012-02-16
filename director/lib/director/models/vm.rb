# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Models
  class Vm < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment
    one_to_one  :instance

    def validate
      validates_presence [:deployment_id, :agent_id]
      validates_unique :agent_id
    end

    def apply_spec
      return nil if apply_spec_json.nil?
      Yajl::Parser.parse(apply_spec_json)
    end

    def apply_spec=(spec)
      self.apply_spec_json = Yajl::Encoder.encode(spec)
    end
  end
end
