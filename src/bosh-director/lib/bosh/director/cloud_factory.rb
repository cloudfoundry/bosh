module Bosh::Director
  class CloudFactory
    class << self
      def create
        new(parse_cpi_configs)
      end

      protected

      def parse_cpi_configs
        cpi_configs = Models::Config.latest_set('cpi')
        return nil if cpi_configs.empty? || cpi_configs.nil?

        cpi_configs_raw_manifests = cpi_configs.map(&:raw_manifest)
        manifest_parser = CpiConfig::CpiManifestParser.new
        merged_cpi_configs_hash = manifest_parser.merge_configs(cpi_configs_raw_manifests)
        manifest_parser.parse(merged_cpi_configs_hash)
      end
    end

    def initialize(parsed_cpi_config)
      @parsed_cpi_config = parsed_cpi_config
      @director_uuid = Config.uuid
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

    def get(cpi_name, stemcell_api_version = nil)
      if cpi_name.nil? || cpi_name == ''
        cloud = get_default_cloud(stemcell_api_version)
      else
        cpi_config = get_cpi_config(cpi_name)
        cloud = Bosh::Clouds::ExternalCpi.new(
          cpi_config.exec_path,
          @director_uuid,
          @logger,
          properties_from_cpi_config: cpi_config.properties,
          stemcell_api_version: stemcell_api_version
        )
      end

      begin
        info_response = cloud.info || {}
        cpi_api_version = info_response.fetch('api_version', 1)
      rescue
        cpi_api_version = 1
      end
      supported_cpi_version = [cpi_api_version, Bosh::Director::Config.preferred_cpi_api_version].min
      @logger.debug("Using cpi_version #{supported_cpi_version} for CPI #{cpi_name}")
      Bosh::Clouds::ExternalCpiResponseWrapper.new(cloud, supported_cpi_version)
    end

    private

    def get_default_cloud(stemcell_api_version)
      Bosh::Clouds::ExternalCpi.new(
        Config.cloud_options['provider']['path'],
        @director_uuid,
        @logger,
        stemcell_api_version: stemcell_api_version,
      )
    end

    def get_cpi_config(cpi_name)
      raise "CPI '#{cpi_name}' not found in cpi-config (because cpi-config is not set)" unless uses_cpi_config?

      cpi_config = @parsed_cpi_config.find_cpi_by_name(cpi_name)
      raise "CPI '#{cpi_name}' not found in cpi-config" if cpi_config.nil?

      cpi_config
    end
  end
end
