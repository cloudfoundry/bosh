module Bosh::Clouds
  class Provider
    def self.create(cloud_config, director_uuid)
      if cloud_config.fetch('external_cpi', {}).fetch('enabled', false)
        ExternalCpiProvider.create(cloud_config['external_cpi'], director_uuid)
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
        raise CloudError, "Could not load Cloud Provider Plugin: #{plugin}, with error #{error.inspect}"
      end

      Bosh::Clouds.const_get(plugin.capitalize).new(options)
    end
  end

  class ExternalCpiProvider
    def self.create(external_cpi_config, director_uuid)
      ExternalCpi.new(external_cpi_config['cpi_path'], director_uuid)
    end
  end
end
