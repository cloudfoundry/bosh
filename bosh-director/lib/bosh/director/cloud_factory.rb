module Bosh::Director
  class CloudFactory
    def self.create_from_deployment(deployment, cpi_config = Bosh::Director::Api::CpiConfigManager.new.latest)
      planner = nil
      planner = create_cloud_planner(deployment.cloud_config) unless deployment.nil?

      new(planner, parse_cpi_config(cpi_config))
    end
    
    def self.parse_cpi_config(cpi_config)
      return nil if cpi_config.nil?
      Bosh::Director::CpiConfig::CpiManifestParser.new.parse(cpi_config.manifest)
    end

    def self.create_cloud_planner(cloud_config)
      return nil if cloud_config.nil?

      global_network_resolver = DeploymentPlan::NullGlobalNetworkResolver.new
      parser = DeploymentPlan::CloudManifestParser.new(Config.logger)
      parser.parse(cloud_config.manifest, global_network_resolver, nil)
    end

    def initialize(cloud_planner, parsed_cpi_config)
      @cloud_planner = cloud_planner
      @parsed_cpi_config = parsed_cpi_config
    end

    def uses_cpi_config?
      !@parsed_cpi_config.nil?
    end

    # used when all cpis must be spoken to, i.e. when uploading stemcells.
    def all_from_cpi_config
      return [] unless uses_cpi_config?
      @parsed_cpi_config.cpis.map{|cpi|create_from_cpi_config(cpi)}
    end

    def for_availability_zone(az_name)
      # instance/disk can have no AZ, pick default CPI then
      return default_from_director_config if az_name.nil?

      cpi_for_az = lookup_cpi_for_az(az_name)
      # instance/disk can have AZ without cpi, pick default CPI then
      return default_from_director_config if cpi_for_az.nil?

      configured_cpi = from_cpi_config(cpi_for_az)
      raise 'CPI was defined for AZ but not found in cpi-config' if configured_cpi.nil?
      create_from_cpi_config(configured_cpi)
    end

    def from_cpi_config(cpi_name)
      return nil unless uses_cpi_config?
      @parsed_cpi_config.find_cpi_by_name(cpi_name)
    end

    def default_from_director_config
      Config.cloud
    end

    private
    def lookup_cpi_for_az(az_name)
      return nil if @cloud_planner.nil?
      az = @cloud_planner.availability_zone(az_name)
      az.nil? ? nil : az.cpi
    end

    def create_from_cpi_config(cpi)
      Bosh::Clouds::ExternalCpi.new(cpi.job_path, Config.uuid, cpi.properties)
    end
  end
end