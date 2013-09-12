module Bosh::Agent
  module Platform::Linux
    class Adapter
      require 'bosh_agent/platform/linux/disk'
      require 'bosh_agent/platform/linux/logrotate'
      require 'bosh_agent/platform/linux/network'
      require 'bosh_agent/platform/linux/password'

      def initialize(disk, logrotate, password, network)
        @disk = disk
        @logrotate = logrotate
        @password = password
        @network = network
      end

      def mount_persistent_disk(cid)
        @disk.mount_persistent_disk(cid)
      end

      def update_logging(spec)
        @logrotate.install(spec)
      end

      def update_passwords(settings)
        @password.update(settings)
      end

      def lookup_disk_by_cid(cid)
        @disk.lookup_disk_by_cid(cid)
      end

      def get_data_disk_device_name
        @disk.get_data_disk_device_name
      end

      def setup_networking
        @network.setup_networking
      end
    end
  end
end
