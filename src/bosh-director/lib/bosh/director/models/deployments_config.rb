module Bosh::Director::Models
  class DeploymentsConfig < Sequel::Model(Bosh::Director::Config.db)
    many_to_one  :deployment
    many_to_one  :config

    dataset_module do
      def by_deployment_name(name)
        association_join(:deployment).filter(Sequel.qualify('deployment', 'name') => name)
      end
    end

    def validate
      validates_presence :deployment
      validates_presence :config
    end
  end
end
