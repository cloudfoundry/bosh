# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Infrastructure::Warden::Settings

    def initialize
      @logger = Bosh::Agent::Config.logger
      @settings_file = Bosh::Agent::Config.settings_file
    end

    def load_settings
      load_settings_file
      Bosh::Agent::Config.settings = @settings
    end

    def load_settings_file
      if File.exists?(@settings_file)
        settings_json = File.read(@settings_file)
        @settings = Yajl::Parser.parse(settings_json)
      else
        raise LoadSettingsError, "No settings file #{@settings_file}"
      end
    end

  end
end
