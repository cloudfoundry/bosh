module Bosh::Director
  class AZCloudFactory < CloudFactory
    class << self
      def create_with_latest_configs(deployment)
        teams = deployment.teams
        cloud_configs = Models::Config.latest_set_for_teams('cloud', *teams)

        azs = create_azs(cloud_configs, deployment.name)

        new(parse_cpi_configs, azs)
      end

      def create_from_deployment(deployment)
        azs = create_azs(deployment.cloud_configs, deployment.name)

        new(parse_cpi_configs, azs)
      end

      protected

      def create_azs(cloud_configs, deployment_name = nil)
        return nil unless CloudConfig::CloudConfigsConsolidator.have_cloud_configs?(cloud_configs)
        parser = DeploymentPlan::CloudManifestParser.new(Config.logger)
        interpolated = Api::CloudConfigManager.interpolated_manifest(cloud_configs, deployment_name)
        parser.parse_availability_zones(interpolated)
              .map { |az| [az.name, az] }
              .to_h
      end
    end

    def initialize(parsed_cpi_config, azs)
      super(parsed_cpi_config)
      @azs = azs
    end

    def get_for_az(az_name, stemcell_api_version = nil)
      cpi_name = get_name_for_az(az_name)

      begin
        get(cpi_name, stemcell_api_version)
      rescue RuntimeError => e
        raise "Failed to load CPI for AZ '#{az_name}': #{e.message}"
      end
    end

    def get_name_for_az(az_name)
      return '' if az_name == '' || az_name.nil?

      raise 'AZs must be given to lookup cpis from AZ' if @azs.nil?

      az = @azs[az_name]
      raise "AZ '#{az_name}' not found in cloud config" if az.nil?

      cpi = az.cpi.nil? ? '' : az.cpi

      if uses_cpi_config? && cpi == ''
        raise Bosh::Director::CpiNotFound, "AZ '#{az_name}' must specify a CPI when CPI config is defined."
      end

      cpi
    end
  end
end
