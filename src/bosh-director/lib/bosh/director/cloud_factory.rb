# Cloud factory looks up and instantiates clouds, either taken from the director config or from the cpi config.
# To achieve this, it uses the parsed cpis from the cpi config.
# For lookup based on availability zone, it additionally needs the cloud planner which contains the AZ -> CPI mapping from the cloud config.
module Bosh::Director
  class CloudFactory
    def self.create_from_deployment(deployment,
        cpi_config = Bosh::Director::Api::CpiConfigManager.new.latest)

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
      @default_cloud = Config.cloud
      @logger = Config.logger
    end

    def uses_cpi_config?
      !@parsed_cpi_config.nil?
    end

    # used when all cpis must be spoken to, i.e. when uploading stemcells.
    def all_configured_clouds
      if uses_cpi_config?
        all_from_cpi_config
      else
        [ {name: '', cpi: default_from_director_config } ]
      end
    end

    def for_availability_zone!(az_name)
      # instance/disk can have no AZ, pick default CPI then
      return default_from_director_config if az_name.nil?

      cpi_for_az = lookup_cpi_for_az(az_name)
      # instance/disk can have AZ without cpi, pick default CPI then
      return default_from_director_config if cpi_for_az.nil?

      cloud = for_cpi(cpi_for_az)
      raise "CPI was defined for AZ #{az_name} but not found in cpi-config" if cloud.nil?
      cloud
    end

    def for_availability_zone(az_name)
      return all_configured_clouds_with_default if az_name.nil?

      az = lookup_az(az_name)
      return all_configured_clouds_with_default if az.nil? || az.cpi.nil?

      cloud = for_cpi(az.cpi)
      return all_configured_clouds_with_default if cloud.nil?
      cloud
    end

    def lookup_cpi_for_az(az_name)
      az = lookup_az(az_name)
      raise "AZ #{az_name} not found in cloud config" if az.nil?
      az.cpi
    end

    def for_cpi(cpi_name)
      configured_cpi = cpi_from_config(cpi_name)
      return nil if configured_cpi.nil?
      create_from_cpi_config(configured_cpi)
    end

    def default_from_director_config
      @default_cloud
    end

    private

    def lookup_az(az_name)
      raise 'Deployment plan must be given to lookup cpis from AZ' if @cloud_planner.nil?
      raise 'AZ name must not be nil' if az_name.nil?

      @cloud_planner.availability_zone(az_name)
    end

    def all_configured_clouds_with_default
      clouds = [{name: '', cpi: default_from_director_config }]

      if uses_cpi_config?
        all_from_cpi_config.each do |cpi|
          clouds << cpi
        end
      end

      CloudCollection.new(clouds, @logger)
    end

    def all_from_cpi_config
      return [] unless uses_cpi_config?
      @parsed_cpi_config.cpis.map{|cpi| {name: cpi.name, cpi: create_from_cpi_config(cpi)} }
    end

    def cpi_from_config(cpi_name)
      return nil unless uses_cpi_config?
      @parsed_cpi_config.find_cpi_by_name(cpi_name)
    end

    def create_from_cpi_config(cpi)
      Bosh::Clouds::ExternalCpi.new(cpi.exec_path, Config.uuid, cpi.properties)
    end
  end
end
