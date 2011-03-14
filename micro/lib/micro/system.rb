module VCAP
  module Micro
    class System
      def self.mounts
        if File.blockdev?('/dev/sdb1')
          `swapon /dev/sdb1`
        end
        if File.blockdev?('/dev/sdb2') && !Pathname.new('/var/vcap/data').mountpoint?
          `mount /dev/sdb2 /var/vcap/data`
        end
        if File.blockdev?('/dev/sdc1') && !Pathname.new('/var/vcap/store').mountpoint?
          `mount /dev/sdc1 /var/vcap/store`
        end
      end
    end
  end
end
