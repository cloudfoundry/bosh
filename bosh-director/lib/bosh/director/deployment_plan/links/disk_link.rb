module Bosh::Director
  module DeploymentPlan
    class DiskLink
      def initialize(disk_name)
        @disk_name = disk_name
      end

      def spec
        {
          'properties' => {'name' => @disk_name},
          'networks' => [],
          'instances' => [],
        }
      end
    end
  end
end
