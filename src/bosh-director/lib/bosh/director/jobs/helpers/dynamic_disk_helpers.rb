module Bosh::Director
  module Jobs::Helpers
    module DynamicDiskHelpers
      def find_disk_cloud_properties(instance, disk_pool_name)
        teams = instance.deployment.teams
        configs = Models::Config.latest_set_for_teams('cloud', *teams)
        raise 'No cloud configs provided' if configs.empty?

        consolidated_configs = Bosh::Director::CloudConfig::CloudConfigsConsolidator.new(configs)
        cloud_config_disk_type = DeploymentPlan::CloudManifestParser.new(logger).parse(consolidated_configs.raw_manifest).disk_type(disk_pool_name)
        raise "Could not find disk pool by name `#{disk_pool_name}`" if cloud_config_disk_type.nil?

        cloud_config_disk_type.cloud_properties
      end

      def nats_rpc
        Config.nats_rpc
      end
    end
  end
end