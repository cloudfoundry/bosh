# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Infrastructure::Dummy

    def load_settings
    end

    def get_network_settings(_, properties)
      # Nothing to do
    end


    def network_config_type
    end
  end
end
