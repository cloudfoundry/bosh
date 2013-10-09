require 'bosh_agent/disk_util'

module Bosh::Agent
  module Message
    class ListDisk < Base
      def self.process(args = nil)
        disk_info = []
        settings = Bosh::Agent::Config.settings

        if settings["disks"].kind_of?(Hash) && settings["disks"]["persistent"].kind_of?(Hash)
          cids = settings["disks"]["persistent"]
        else
          cids = {}
        end

        cids.each_key do |cid|
          disk = Bosh::Agent::Config.platform.lookup_disk_by_cid(cid)
          partition = "#{disk}1"
          disk_info << cid unless DiskUtil.mount_entry(partition).nil?
        end
        disk_info
      end
    end
  end
end
