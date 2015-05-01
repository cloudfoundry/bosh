module Bosh
  module Director
    module Api
      class CloudConfigManager
        def update(cloud_config_yaml)
          cloud_config = Bosh::Director::Models::CloudConfig.new(
            properties: cloud_config_yaml
          )
          validate_manifest(cloud_config)
          cloud_config.save
        end

        def list(limit)
          Bosh::Director::Models::CloudConfig.order(Sequel.desc(:id)).limit(limit).to_a
        end

        def latest
          list(1).first
        end

        private

        def validate_manifest(cloud_config)
          deployment = Bosh::Director::DeploymentPlan::CloudPlanner.new(cloud_config)
          parser = Bosh::Director::DeploymentPlan::CloudManifestParser.new(deployment, Config.logger)
          parser.parse(cloud_config.manifest)
        end
      end
    end
  end
end
