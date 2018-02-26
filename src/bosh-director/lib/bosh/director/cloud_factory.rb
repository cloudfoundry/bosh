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
  end
end
