module Bosh::Director::Models
  class Event < Sequel::Model(Bosh::Director::Config.db)

    def validate
      validates_presence [:timestamp, :action, :object_type]
    end

    def context
      return {} if context_json.nil?
      JSON.parse(context_json)
    end

    def context=(data)
      self.context_json = JSON.generate(data.nil? ? {} : data)
    end
  end
end
