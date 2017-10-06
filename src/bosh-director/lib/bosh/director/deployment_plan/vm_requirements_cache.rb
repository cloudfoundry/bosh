module Bosh::Director
  module DeploymentPlan
    class VmRequirementsCache
      def initialize(cloud_factory, logger)
        @cloud_factory = cloud_factory
        @cached_cloud_properties = {}
        @logger = logger
      end

      def get_vm_cloud_properties(cpi_name, vm_requirements_hash)
        key = {cpi_name => vm_requirements_hash}
        @cached_cloud_properties.fetch(key) do
          @cached_cloud_properties[key] = calculate_vm_cloud_properties(cpi_name, vm_requirements_hash)
        end
      end

      private

      def calculate_vm_cloud_properties(cpi_name, vm_requirements_hash)
        cpi = @cloud_factory.get(cpi_name)
        vm_cloud_properties = cpi.calculate_vm_cloud_properties(vm_requirements_hash)
        @logger.info("CPI #{cpi_name} calculated vm cloud properties '#{vm_cloud_properties}' for vm requirements '#{vm_requirements_hash}'")
        vm_cloud_properties
      end

    end
  end
end