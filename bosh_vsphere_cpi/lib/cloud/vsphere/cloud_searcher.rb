require 'common/common'

module VSphereCloud
  class CloudSearcher
    include VimSdk

    class MissingPropertiesException < StandardError; end

    PC = Vmodl::Query::PropertyCollector

    def initialize(service_content, logger)
      @service_content = service_content
      @logger = logger
    end

    def get_property(obj, type, property, options = {})
      get_properties(obj, type, property, options)[property]
    end

    def get_properties(obj, type, properties, options = {})
      properties = [properties] if properties.kind_of?(String)
      property_specs = [PC::PropertySpec.new(:type => type, :all => false, :path_set => properties)]

      if obj.is_a?(Vmodl::ManagedObject)
        object_spec = PC::ObjectSpec.new(:obj => obj, :skip => false)
      else
        object_spec = obj.collect { |o| PC::ObjectSpec.new(:obj => o, :skip => false) }
      end

      filter_spec = PC::FilterSpec.new(:prop_set => property_specs, :object_set => object_spec)
      
      # Bosh::Common.retryable default has an exponential sleeper,
      # with 30 tries the timeout will be ~265s
      errors = [MissingPropertiesException]
      Bosh::Common.retryable(tries: 30, on: errors) do |tries, error|
        properties_response = get_all_properties(filter_spec)
        result = {}

        properties_response.each do |object_content|
          object_properties = {:obj => object_content.obj}
          if options[:ensure_all]
            remaining_properties = Set.new(properties)
          else
            remaining_properties = Set.new(options[:ensure])
          end
          if object_content.prop_set
            object_content.prop_set.each do |property|
              object_properties[property.name] = property.val
              remaining_properties.delete(property.name)
            end
          end
          unless remaining_properties.empty?
            raise MissingPropertiesException.new("The object[s] #{obj} " +
              "should have the following properties: #{properties.pretty_inspect}, " +
              "but they were missing these: #{remaining_properties.pretty_inspect}.")
          end
          result[object_content.obj] = object_properties
        end

        result = result.values.first if obj.is_a?(Vmodl::ManagedObject)
        result
      end
    end

    def get_all_properties(filter_spec)
      result = []
      retrieve_result = @service_content.property_collector.retrieve_properties_ex([filter_spec],
        PC::RetrieveOptions.new)
      until retrieve_result.nil?
        retrieve_result.objects.each { |object_content| result << object_content }
        break if retrieve_result.token.nil?
        retrieve_result = @service_content.property_collector.continue_retrieve_properties_ex(retrieve_result.token)
      end
      result
    end

    def get_managed_objects(type, options={})
      object_specs = get_object_specs(type, options[:root], 'name')

      result = []
      object_specs.each do |object_spec|
        name = object_spec.prop_set.first.val
        if options[:name].nil? || name == options[:name]
          if options[:include_name]
            result << [name , object_spec.obj]
          else
            result << object_spec.obj
          end
        end
      end
      result
    end

    def get_managed_object(type, options)
      result = get_managed_objects(type, options)
      raise "Could not find #{type}: #{options.pretty_inspect}" if result.length == 0
      raise "Found more than one #{type}: #{options.pretty_inspect}" if result.length > 1
      result.first
    end

    def get_managed_objects_with_attribute(type, custom_field_key, options = {})
      object_specs = get_object_specs(type, options[:root], 'customValue')

      results = []
      object_specs.each do |object|

        catch(:found_object) do
          object.prop_set.each do |property|
            property.val.each do |property_value|

              if property_value.key == custom_field_key
                if options[:value].nil? || property_value.value == options[:value]
                  results << object.obj
                  throw :found_object
                end
              end

            end
          end
        end
      end

      results
    end

    def has_managed_object_with_attribute?(type, custom_field_key, options = {})
      object_specs = get_object_specs(type, options[:root], 'customValue')

      object_specs.each do |object|
        object.prop_set.each do |property|
          property.val.each do |property_value|
            if property_value.key == custom_field_key
              if options[:value].nil? || property_value.value == options[:value]
                return true
              end
            end
          end
        end
      end

      false
    end

    private

    def get_object_specs(type, root, path_set)
      root ||= @service_content.root_folder

      property_specs = [PC::PropertySpec.new(:type => type, :all => false, :path_set => [path_set])]
      filter_spec = get_search_filter_spec(root, property_specs)
      get_all_properties(filter_spec)
    end

    def get_search_filter_spec(obj, property_specs)
      resource_pool_traversal_spec = PC::TraversalSpec.new(
        :name => "resourcePoolTraversalSpec",
        :type => Vim::ResourcePool,
        :path => "resourcePool",
        :skip => false,
        :select_set => [
          PC::SelectionSpec.new(:name => "resourcePoolTraversalSpec"),
          PC::SelectionSpec.new(:name => "resourcePoolVmTraversalSpec")
        ]
      )

      resource_pool_vm_traversal_spec = PC::TraversalSpec.new(
        :name => "resourcePoolVmTraversalSpec",
        :type => Vim::ResourcePool,
        :path => "vm",
        :skip => false
      )

      compute_resource_rp_traversal_spec = PC::TraversalSpec.new(
        :name => "computeResourceRpTraversalSpec",
        :type => Vim::ComputeResource,
        :path => "resourcePool",
        :skip => false,
        :select_set => [
          PC::SelectionSpec.new(:name => "resourcePoolTraversalSpec"),
          PC::SelectionSpec.new(:name => "resourcePoolVmTraversalSpec")
        ]
      )

      compute_resource_datastore_traversal_spec = PC::TraversalSpec.new(
        :name => "computeResourceDatastoreTraversalSpec",
        :type => Vim::ComputeResource,
        :path => "datastore",
        :skip => false
      )

      compute_resource_host_traversal_spec = PC::TraversalSpec.new(
        :name => "computeResourceHostTraversalSpec",
        :type => Vim::ComputeResource,
        :path => "host",
        :skip => false
      )

      datacenter_host_traversal_spec = PC::TraversalSpec.new(
        :name => "datacenterHostTraversalSpec",
        :type => Vim::Datacenter,
        :path => "hostFolder",
        :skip => false,
        :select_set => [
          PC::SelectionSpec.new(:name => "folderTraversalSpec")
        ]
      )

      datacenter_vm_traversal_spec = PC::TraversalSpec.new(
        :name => "datacenterVmTraversalSpec",
        :type => Vim::Datacenter,
        :path => "vmFolder",
        :skip => false,
        :select_set => [
          PC::SelectionSpec.new(:name => "folderTraversalSpec")
        ]
      )

      host_vm_traversal_spec = PC::TraversalSpec.new(
        :name => "hostVmTraversalSpec",
        :type => Vim::HostSystem,
        :path => "vm",
        :skip => false,
        :select_set => [
          PC::SelectionSpec.new(:name => "folderTraversalSpec")
        ]
      )

      folder_traversal_spec = PC::TraversalSpec.new(
        :name => "folderTraversalSpec",
        :type => Vim::Folder,
        :path => "childEntity",
        :skip => false,
        :select_set => [
          PC::SelectionSpec.new(:name => "folderTraversalSpec"),
          PC::SelectionSpec.new(:name => "datacenterHostTraversalSpec"),
          PC::SelectionSpec.new(:name => "datacenterVmTraversalSpec"),
          PC::SelectionSpec.new(:name => "computeResourceRpTraversalSpec"),
          PC::SelectionSpec.new(:name => "computeResourceDatastoreTraversalSpec"),
          PC::SelectionSpec.new(:name => "computeResourceHostTraversalSpec"),
          PC::SelectionSpec.new(:name => "hostVmTraversalSpec"),
          PC::SelectionSpec.new(:name => "resourcePoolVmTraversalSpec")
        ]
      )

      obj_spec = PC::ObjectSpec.new(
        :obj => obj,
        :skip => false,
        :select_set => [
          folder_traversal_spec,
          datacenter_vm_traversal_spec,
          datacenter_host_traversal_spec,
          compute_resource_host_traversal_spec,
          compute_resource_datastore_traversal_spec,
          compute_resource_rp_traversal_spec,
          resource_pool_traversal_spec,
          host_vm_traversal_spec,
          resource_pool_vm_traversal_spec
        ]
      )

      PC::FilterSpec.new(:prop_set => property_specs, :object_set => [obj_spec])
    end
  end
end
