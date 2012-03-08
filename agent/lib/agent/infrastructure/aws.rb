
module Bosh::Agent
  class Infrastructure::Aws
    require 'sigar'
    require 'agent/infrastructure/aws/settings'
    require 'agent/infrastructure/aws/registry'

    def load_settings
      Settings.new.load_settings
    end

    def get_network_settings
      Settings.new.get_network_settings
    end

  end
end
