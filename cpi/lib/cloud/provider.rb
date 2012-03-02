module Bosh::Clouds
  class Provider

    def self.create(plugin, options)
      begin
        require "cloud/#{plugin}"
      rescue LoadError
        raise CloudError, "Could not find Cloud Provider Plugin: #{plugin}"
      end
      Bosh::Clouds.const_get(plugin.capitalize).new(options)
    end

  end
end
