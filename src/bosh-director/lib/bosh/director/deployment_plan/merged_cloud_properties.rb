module Bosh::Director::DeploymentPlan
  class MergedCloudProperties
    def initialize(availability_zone, vm_type, vm_extensions)
      @availability_zone = availability_zone
      @vm_type = vm_type
      @vm_extensions = vm_extensions
    end

    def get
      merged_cloud_properties = nil

      merged_cloud_properties = merge_cloud_properties(merged_cloud_properties, @availability_zone.cloud_properties) unless @availability_zone.nil?

      merged_cloud_properties = merge_cloud_properties(merged_cloud_properties, @vm_type.cloud_properties) unless @vm_type.nil?

      Array(@vm_extensions).each do |vm_extension|
        merged_cloud_properties = merge_cloud_properties(merged_cloud_properties, vm_extension.cloud_properties)
      end

      merged_cloud_properties
    end

    private

    def merge_cloud_properties(merged_cloud_properties, new_cloud_properties)
      merged_cloud_properties.nil? ? new_cloud_properties : merged_cloud_properties.merge(new_cloud_properties)
    end
  end
end
