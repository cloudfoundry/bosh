module Bosh::Director
  module DeploymentPlan
    class DiskLink
      def initialize(deployment_name, disk_name)
        @deployment_name = deployment_name
        @disk_name = disk_name
      end

      def spec
        {
          'deployment_name' => @deployment_name,
          'properties' => {'name' => @disk_name},
          'networks' => [],
          'instances' => [],
        }
      end
    end
  end
end
