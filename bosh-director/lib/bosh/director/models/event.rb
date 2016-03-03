# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Models
  class Event < Sequel::Model(Bosh::Director::Config.db)
    def validate
      validates_presence [:timestamp, :action, :object_type]
    end

    def context
      return {} if context_json.nil?
      Yajl::Parser.parse(context_json)
    end

    def context=(data)
      self.context_json = Yajl::Encoder.encode(data)
    end
  end
end
