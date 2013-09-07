# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class UnknownPlatform < StandardError; end

  module Platform
    def self.platform(platform_name)
      case platform_name
        when 'ubuntu'
          Ubuntu::Adapter.new
        when 'centos'
          Centos.new
        when 'rhel'
          Rhel.new
        else
          raise UnknownPlatform, "platform '#{platform_name}' not found"
      end
    end
  end
end
