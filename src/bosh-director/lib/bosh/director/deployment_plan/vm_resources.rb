module Bosh::Director
  module DeploymentPlan
    class VmResources
      include ValidationHelper

      attr_reader :cpu

      attr_reader :ram

      attr_reader :ephemeral_disk_size

      def initialize(spec)
        @cpu = safe_property(spec, 'cpu', class: Integer)
        @ram = safe_property(spec, 'ram', class: Integer)
        @ephemeral_disk_size = safe_property(spec, 'ephemeral_disk_size', class: Integer)
      end

      def spec
        {
          'cpu' => @cpu,
          'ram' => @ram,
          'ephemeral_disk_size' => @ephemeral_disk_size,
        }
      end
    end
  end
end
