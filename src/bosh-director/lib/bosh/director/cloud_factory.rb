# Cloud factory looks up and instantiates clouds, either taken from the director config or from the cpi config.
# To achieve this, it uses the parsed cpis from the cpi config.
# For lookup based on availability zone, it additionally needs the cloud planner which contains the AZ -> CPI mapping from the cloud config.
require 'bosh/director/validation_helper'

module Bosh::Director
  class CloudFactory
    extend ValidationHelper

    def self.create_with_latest_configs(deployment = nil)
      cpi_configs = Bosh::Director::Models::Config.latest_set('cpi')
      cloud_configs = Bosh::Director::Models::Config.latest_set('cloud')

      azs = if deployment.nil?
                  create_azs(cloud_configs)
                else
                  create_azs(cloud_configs, deployment.name)
                end

      new(azs, parse_cpi_configs(cpi_configs))
    end

    def self.create_from_deployment(deployment,
                                    cpi_configs = Bosh::Director::Models::Config.latest_set('cpi'))
      azs = create_azs(deployment.cloud_configs, deployment.name) unless deployment.nil?

      new(azs, parse_cpi_configs(cpi_configs))
    end

    def self.parse_cpi_configs(cpi_configs)
      return nil if cpi_configs.nil? || cpi_configs.empty?

      cpi_configs_raw_manifests = cpi_configs.map(&:raw_manifest)
      manifest_parser = Bosh::Director::CpiConfig::CpiManifestParser.new
      merged_cpi_configs_hash = manifest_parser.merge_configs(cpi_configs_raw_manifests)
      manifest_parser.parse(merged_cpi_configs_hash)
    end

    def self.create_cloud_planner(cloud_configs, deployment_name = nil)
      return nil unless CloudConfig::CloudConfigsConsolidator.have_cloud_configs?(cloud_configs)

      global_network_resolver = DeploymentPlan::NullGlobalNetworkResolver.new
      parser = DeploymentPlan::CloudManifestParser.new(Config.logger)
      parser.parse(Api::CloudConfigManager.interpolated_manifest(cloud_configs, deployment_name), global_network_resolver, nil)
    end

    def self.create_azs(cloud_configs, deployment_name = nil)
      return nil unless CloudConfig::CloudConfigsConsolidator.have_cloud_configs?(cloud_configs)

      interpolated = Api::CloudConfigManager.interpolated_manifest(cloud_configs, deployment_name)
      azs = Bosh::Director::DeploymentPlan::AvailabilityZone.parse(interpolated)
      Bosh::Director::DeploymentPlan::CloudPlanner.index_by_name(azs)
    end

    def initialize(azs, parsed_cpi_config)
      @azs = azs
      @parsed_cpi_config = parsed_cpi_config
      @default_cloud = Config.cloud
      @logger = Config.logger
    end

    def uses_cpi_config?
      !@parsed_cpi_config.nil?
    end

    def all_names
      return [''] unless uses_cpi_config?

      @parsed_cpi_config.cpis.map(&:name)
    end

    def get_cpi_aliases(cpi_name)
      return [''] unless uses_cpi_config?

      cpi_config = get_cpi_config(cpi_name)

      [cpi_name] + cpi_config.migrated_from_names
    end

    def get(cpi_name)
      return @default_cloud if cpi_name.nil? || cpi_name == ''
      cpi_config = get_cpi_config(cpi_name)
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
      return '' if az_name == '' || az_name.nil?

      raise 'AZs must be given to lookup cpis from AZ' if @azs.nil?

      az = @azs[az_name]
      raise "AZ '#{az_name}' not found in cloud config" if az.nil?

      az.cpi.nil? ? '' : az.cpi
    end

    private

    def get_cpi_config(cpi_name)
      raise "CPI '#{cpi_name}' not found in cpi-config (because cpi-config is not set)" unless uses_cpi_config?

      cpi_config = @parsed_cpi_config.find_cpi_by_name(cpi_name)
      raise "CPI '#{cpi_name}' not found in cpi-config" if cpi_config.nil?

      cpi_config
    end
  end
end
