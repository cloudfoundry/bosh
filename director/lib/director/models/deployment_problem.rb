module Bosh::Director::Models
  class DeploymentProblem < Sequel::Model

    many_to_one :deployment

    STATES = %w(open closed resolved)

    def validate
      validates_presence :deployment_id
      validates_presence :resource_id
      validates_presence :type
      validates_presence :data_json
      validates_presence :state
      validates_includes STATES, :state
    end

    def before_create
      self.created_at ||= Time.now
      self.last_seen_at ||= Time.now
    end

    def data
      Yajl::Parser.parse(data_json)
    end

    def data=(raw_data)
      self.data_json = Yajl::Encoder.encode(raw_data)
    end

    def resolutions
      handler = ProlemHandlers::Base.create_from_model(self)
      handler.resolutions
    end

  end
end
