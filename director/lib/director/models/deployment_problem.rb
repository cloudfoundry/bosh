module Bosh::Director::Models
  class DeploymentProblem < Sequel::Model(Bosh::Director::Config.db)

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

    def handler
      @handler ||= Bosh::Director::ProblemHandlers::Base.create_from_model(self)
    end

    def resolutions
      handler.resolutions
    end

    def description
      handler.description
    end

  end
end
