module Bosh::Director
  class CloudFactory
    def self.create_from_cpi_config(cpi_config = Bosh::Director::Api::CpiConfigManager.new.latest)
      parsed = unless cpi_config.nil?
                 Bosh::Director::CpiConfig::CpiManifestParser.new.parse(cpi_config.manifest)
               else
                 nil
               end
      new(parsed)
    end

    def initialize(parsed_cpi_config)
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

    def from_cpi_config_or_default(cpi_name)
      return default_from_director_config if cpi_name.nil?
      configured_cpi = from_cpi_config(cpi_name)
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
    def create_from_cpi_config(cpi)
      Bosh::Clouds::ExternalCpi.new(cpi.job_path, Config.uuid, cpi.properties)
    end
  end
end