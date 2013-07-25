# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Infrastructure::Dummy

    def load_settings
      {
        "blobstore" => {
          "provider" => Bosh::Agent::Config.blobstore_provider,
          "options" => Bosh::Agent::Config.blobstore_options,
        },
        "ntp" => [],
        "disks" => {
          "persistent" => {},
        },
        "mbus" => Bosh::Agent::Config.mbus,
      }
    end

    def get_network_settings(network_name, properties)
      # Nothing to do
    end
  end
end
