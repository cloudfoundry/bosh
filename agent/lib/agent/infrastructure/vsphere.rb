
module Bosh::Agent
  class Infrastructure::Vsphere
    require 'agent/infrastructure/vsphere/settings'

    def load_settings
      Settings.new.load_settings
    end

  end
end
