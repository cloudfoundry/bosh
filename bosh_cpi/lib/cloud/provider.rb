module Bosh::Clouds
  class Provider
    def self.create(cloud_config)
      if cloud_config.fetch('external_cpi',{}).fetch('enabled', false)
        ExternalCpiProvider.create(cloud_config['external_cpi'])
      else
        PluginCloudProvider.create(cloud_config['plugin'], cloud_config['properties'])
      end
    end
  end

  private

  class PluginCloudProvider
    def self.create(plugin, options)
      begin
        require "cloud/#{plugin}"
      rescue LoadError => error
        raise CloudError, "Could not load Cloud Provider Plugin: #{plugin}"
      end

      Bosh::Clouds.const_get(plugin.capitalize).new(options)
    end
  end

  class ExternalCpiProvider
    def self.create(external_cpi_config)
      ExternalCpi.new(external_cpi_config['cpi_path'])
    end
  end
end
