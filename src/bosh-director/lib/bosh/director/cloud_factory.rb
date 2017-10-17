# Cloud factory looks up and instantiates clouds, either taken from the director config or from the cpi config.
# To achieve this, it uses the parsed cpis from the cpi config.
# For lookup based on availability zone, it additionally needs the cloud planner which contains the AZ -> CPI mapping from the cloud config.
module Bosh::Director
  class CloudFactory
    def self.create_with_latest_configs(deployment = nil)
      cpi_config = Bosh::Director::Api::CpiConfigManager.new.latest
      cloud_config = Bosh::Director::Api::CloudConfigManager.new.latest

      if deployment.nil?
        planner = create_cloud_planner(cloud_config)
      else
        planner = create_cloud_planner(cloud_config, deployment.name)
      end

      new(planner, parse_cpi_config(cpi_config))
    end

    def self.create_from_deployment(deployment,
      cpi_config = Bosh::Director::Api::CpiConfigManager.new.latest)
      planner = create_cloud_planner(deployment.cloud_config, deployment.name) unless deployment.nil?

      new(planner, parse_cpi_config(cpi_config))
    end

    def self.parse_cpi_config(cpi_config)
      return nil if cpi_config.nil?
      Bosh::Director::CpiConfig::CpiManifestParser.new.parse(cpi_config.manifest)
    end

    def self.create_cloud_planner(cloud_config, deployment_name = nil)
      return nil if cloud_config.nil?

      global_network_resolver = DeploymentPlan::NullGlobalNetworkResolver.new
      parser = DeploymentPlan::CloudManifestParser.new(Config.logger)
      parser.parse(Api::CloudConfigManager.interpolated_manifest(cloud_config, deployment_name), global_network_resolver, nil)
    end

    def initialize(cloud_planner, parsed_cpi_config)
      @cloud_planner = cloud_planner
      @parsed_cpi_config = parsed_cpi_config
      @default_cloud = Config.cloud
      @logger = Config.logger
    end

    def uses_cpi_config?
      !@parsed_cpi_config.nil?
    end

    def all_names
      if !uses_cpi_config?
        return ['']
      end

      @parsed_cpi_config.cpis.map(&:name)
    end

    def get(cpi_name)
      if cpi_name == nil || cpi_name == '' then
        return @default_cloud
      elsif !uses_cpi_config?
        raise "CPI '#{cpi_name}' not found in cpi-config (because cpi-config is not set)"
      end

      cpi_config = @parsed_cpi_config.find_cpi_by_name(cpi_name)
      raise "CPI '#{cpi_name}' not found in cpi-config" if cpi_config.nil?

      Bosh::Clouds::ExternalCpi.new(cpi_config.exec_path, Config.uuid, cpi_config.properties)
    end

    def get_for_az(az_name)
      cpi_name = get_name_for_az(az_name)

      begin
        get(cpi_name)
      rescue RuntimeError => e
        raise "Failed to load CPI for AZ '#{az_name}': #{e.message}"
      end
    end

    def get_name_for_az(az_name)
      if az_name == '' || az_name == nil then
        return ''
      end

      raise 'Deployment plan must be given to lookup cpis from AZ' if @cloud_planner.nil?

      az = @cloud_planner.availability_zone(az_name)
      raise "AZ '#{az_name}' not found in cloud config" if az.nil?

      az.cpi.nil? ? '' : az.cpi
    end
  end
end
