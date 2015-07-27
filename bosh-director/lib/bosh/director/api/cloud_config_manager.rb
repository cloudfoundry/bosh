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
          ip_provider_factory = Bosh::Director::DeploymentPlan::IpProviderFactory.new(deployment.model, Config.logger, global_networking: deployment.using_global_networking?)
          global_network_resolver = Bosh::Director::DeploymentPlan::GlobalNetworkResolver.new(deployment)
          parser = Bosh::Director::DeploymentPlan::CloudManifestParser.new(deployment, Config.logger)
          parser.parse(cloud_config.manifest, ip_provider_factory, global_network_resolver)
        end
      end
    end
  end
end
