# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class UnknownPlatform < StandardError; end

  module Platform
    def self.platform(platform_name)
      platform = File.join(File.dirname(__FILE__), 'platform', "#{platform_name}.rb")

      if File.exist?(platform)
        require platform
      else
        raise UnknownPlatform, "platform '#{platform_name}' not found"
      end

      Platform.const_get(platform_name.capitalize).new
    end

  end
end
