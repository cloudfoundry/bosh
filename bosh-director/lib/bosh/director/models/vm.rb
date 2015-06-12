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

    # @param [Hash] env_hash Environment hash
    def env=(env_hash)
      self.env_json = Yajl::Encoder.encode(env_hash)
    end

    # @return [Hash] VM environment hash
    def env
      return nil if env_json.nil?
      Yajl::Parser.parse(env_json)
    end

    def credentials
      return nil if credentials_json.nil?
      Yajl::Parser.parse(credentials_json)
    end

    def credentials=(spec)
      self.credentials_json = Yajl::Encoder.encode(spec)
    end
  end
end
