# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class UnknownPlatform < StandardError; end

  class Platform

    def initialize(platform_name)
      @name = platform_name
      # TODO: add to loadpath?
      platform = File.join(File.dirname(__FILE__), 'platform', "#{platform_name}.rb")

      if File.exist?(platform)
        load platform
      else
        raise UnknownPlatform, "platform '#{platform_name}' not found"
      end
    end

    def platform
      Platform.const_get(@name.capitalize).new
    end

  end
end
