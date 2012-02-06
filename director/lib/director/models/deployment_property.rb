module Bosh::Director::Models
  class DeploymentProperty < Sequel::Model(Bosh::Director::Config.db)

    VALID_PROPERTY_NAME = /^[-a-z0-9_.]+$/i

    many_to_one :deployment

    def validate
      validates_presence :deployment_id
      validates_presence :name
      validates_presence :value

      validates_unique [:name, :deployment_id]

      validates_format VALID_PROPERTY_NAME, :name, :allow_blank => true
    end

  end
end
