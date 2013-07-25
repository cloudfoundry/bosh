module Bosh::Clouds
  class Provider

    def self.create(plugin, options)
      begin
        require "cloud/#{plugin}"
      rescue LoadError => error
        raise CloudError, "Could not load Cloud Provider Plugin: #{plugin}"
      end

      Bosh::Clouds.const_get(plugin.capitalize).new(options)
    end

  end
end
