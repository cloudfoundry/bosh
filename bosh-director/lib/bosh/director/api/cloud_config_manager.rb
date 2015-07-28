module Bosh
  module Director
    module Api
      class CloudConfigManager
        def update(cloud_config_yaml)
          cloud_config = Bosh::Director::Models::CloudConfig.new(
            properties: cloud_config_yaml
          )
          validate_manifest!(cloud_config)
          cloud_config.save
        end

        def list(limit)
          Bosh::Director::Models::CloudConfig.order(Sequel.desc(:id)).limit(limit).to_a
        end

        def latest
          list(1).first
        end

        private

        def validate_manifest!(cloud_config)
          # FIXME: pass in null ip/networking objects
          # these objects won't work if you actually try to reserve IPs with them since the cloud_planner is empty,
          # but we really just need to validate the manifest, we don't care about the subnets being able to reserve IPs here
          cloud_planner = Bosh::Director::DeploymentPlan::CloudPlanner.new({
              networks: [],
              disk_pools: [],
              availability_zones: [],
              resource_pools: [],
              compilation: nil,
            })
          ip_provider_factory = Bosh::Director::DeploymentPlan::IpProviderFactory.new(cloud_planner.model, Config.logger, global_networking: cloud_planner.using_global_networking?)
          global_network_resolver = Bosh::Director::DeploymentPlan::GlobalNetworkResolver.new(cloud_planner)

          parser = Bosh::Director::DeploymentPlan::CloudManifestParser.new(Config.logger)
          _ = parser.parse(cloud_config.manifest, ip_provider_factory, global_network_resolver) # valid if this doesn't blow up
        end
      end
    end
  end
end
