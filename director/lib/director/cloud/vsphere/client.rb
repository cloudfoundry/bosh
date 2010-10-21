require "director/cloud/vsphere/defaultDriver"
require "director/cloud/vsphere/lease_updater"

module Bosh::Director::CloudProviders::VSphere

  class Client

    class AlreadyLoggedInException < StandardError; end
    class NotLoggedInException < StandardError; end

    attr_accessor :service_content
    attr_accessor :service

    def initialize(host, options = {})
      @service = VimPortType.new(host)
      @service.options["protocol.http.ssl_config.verify_mode"] = OpenSSL::SSL::VERIFY_NONE
      @service.wiredump_dev = File.open(options["soap_log"], "w") if options["soap_log"]

      service_ref = ManagedObjectReference.new("ServiceInstance")
      service_ref.xmlattr_type = "ServiceInstance"

      retrieve_service_content_request = RetrieveServiceContentRequestType.new(service_ref)
      @service_content = @service.retrieveServiceContent(retrieve_service_content_request).returnval
    end

    def login(username, password, locale)
      raise AlreadyLoggedInException if @session
      login_request = LoginRequestType.new(@service_content.sessionManager, username, password, locale)
      @session = @service.login(login_request).returnval
    end

    def logout
      raise NotLoggedInException unless @session
      @session = nil
      @service.logout(LogoutRequestType.new(@service_content.sessionManager))
    end

    def get_properties(obj, type, properties)
      property_specs = [PropertySpec.new(nil, nil, type, false, properties)]

      if obj.is_a?(ManagedObjectReference)
        object_spec = ObjectSpec.new(nil, nil, obj, false)
      else
        object_spec = obj.collect {|o| ObjectSpec.new(nil, nil, o, false)}
      end

      filter_spec = PropertyFilterSpec.new(nil, nil, property_specs, object_spec)
      properties_request = RetrievePropertiesExRequestType.new(@service_content.propertyCollector, filter_spec,
                                                               RetrieveOptions.new)

      properties_response = get_all_properties(properties_request)
      result = {}

      properties_response.each do |object_content|
        properties = {:obj => object_content.obj}
        if object_content.propSet
          object_content.propSet.each do |property|
            properties[property.name] = property.val
          end
        end
        result[object_content.obj] = properties
      end

      result = result.values[0] if obj.is_a?(String)
      result
    end

    def get_property(obj, type, property)
      get_properties(obj, type, property)[property]
    end

    def get_managed_objects(type, options={})
      root = options[:root] || @service_content.rootFolder

      property_specs = [PropertySpec.new(nil, nil, type, false, ["name"])]
      filter_spec = get_search_filter_spec(root, property_specs)
      retrieve_properties_request = RetrievePropertiesExRequestType.new(@service_content.propertyCollector,
                                                                        filter_spec, RetrieveOptions.new)
      object_specs = get_all_properties(retrieve_properties_request)

      result = []
      object_specs.each do |object_spec|
        name = object_spec.propSet[0].val
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
      result[0]
    end

    def find_by_inventory_path(path)
      path = path.collect {|name| name.gsub("/", "%2f")}.join("/")
      find_request = FindByInventoryPathRequestType.new(@service_content.searchIndex, path)
      @service.findByInventoryPath(find_request).returnval
    end

    def wait_for_task(task, options = {})
      interval = options[:interval] || 1.0
      loop do
        properties = get_properties([task], "Task", ["info.progress", "info.state", "info.result", "info.error"])[task]
        case properties["info.state"]
          when TaskInfoState::Running
            sleep(interval)
          when TaskInfoState::Success
            return properties["info.result"]
          when TaskInfoState::Error
            raise properties["info.error"].localizedMessage
        end
      end
    end

    def get_search_filter_spec(obj, property_specs)
      resource_pool_traversal_spec = TraversalSpec.new(nil, nil, "resourcePoolTraversalSpec", "ResourcePool",
                                                    "resourcePool", false,
                                                    [SelectionSpec.new(nil, nil, "resourcePoolTraversalSpec"),
                                                     SelectionSpec.new(nil, nil, "resourcePoolVmTraversalSpec")])

      resource_pool_vm_traversal_spec = TraversalSpec.new(nil, nil, "resourcePoolVmTraversalSpec", "ResourcePool",
                                                      "vm", false)

      compute_resource_rp_traversal_spec = TraversalSpec.new(nil, nil, "computeResourceRpTraversalSpec",
                                                         "ComputeResource", "resourcePool", false,
                                                         [SelectionSpec.new(nil, nil, "resourcePoolTraversalSpec"),
                                                          SelectionSpec.new(nil, nil, "resourcePoolVmTraversalSpec")])

      compute_resource_datastore_traversal_spec = TraversalSpec.new(nil, nil, "computeResourceDatastoreTraversalSpec",
                                                                "ComputeResource", "datastore", false)

      compute_resource_host_traversal_spec = TraversalSpec.new(nil, nil, "computeResourceHostTraversalSpec",
                                                           "ComputeResource", "host", false)

      datacenter_host_traversal_spec = TraversalSpec.new(nil, nil, "datacenterHostTraversalSpec", "Datacenter",
                                                      "hostFolder", false,
                                                      [SelectionSpec.new(nil, nil, "folderTraversalSpec")])

      datacenter_vm_traversal_spec = TraversalSpec.new(nil, nil, "datacenterVmTraversalSpec", "Datacenter",
                                                    "vmFolder", false,
                                                    [SelectionSpec.new(nil, nil, "folderTraversalSpec")])

      host_vm_traversal_spec = TraversalSpec.new(nil, nil, "hostVmTraversalSpec", "HostSystem",
                                              "vm", false,
                                              [SelectionSpec.new(nil, nil, "folderTraversalSpec")])

      folder_traversal_spec = TraversalSpec.new(nil, nil, "folderTraversalSpec", "Folder",
                                              "childEntity", false,
                                              [SelectionSpec.new(nil, nil, "folderTraversalSpec"),
                                               SelectionSpec.new(nil, nil, "datacenterHostTraversalSpec"),
                                               SelectionSpec.new(nil, nil, "datacenterVmTraversalSpec"),
                                               SelectionSpec.new(nil, nil, "computeResourceRpTraversalSpec"),
                                               SelectionSpec.new(nil, nil, "computeResourceDatastoreTraversalSpec"),
                                               SelectionSpec.new(nil, nil, "computeResourceHostTraversalSpec"),
                                               SelectionSpec.new(nil, nil, "hostVmTraversalSpec"),
                                               SelectionSpec.new(nil, nil, "resourcePoolVmTraversalSpec")])

      obj_spec = ObjectSpec.new(nil, nil, obj, false,
                                [folder_traversal_spec,
                                 datacenter_vm_traversal_spec,
                                 datacenter_host_traversal_spec,
                                 compute_resource_host_traversal_spec,
                                 compute_resource_datastore_traversal_spec,
                                 compute_resource_rp_traversal_spec,
                                 resource_pool_traversal_spec,
                                 host_vm_traversal_spec,
                                 resource_pool_vm_traversal_spec])

      PropertyFilterSpec.new(nil, nil, property_specs, [obj_spec])
    end

    def get_all_properties(request)
      response = @service.retrievePropertiesEx(request).returnval
      result = []

      until response.nil?
        response.objects.each {|object_content| result << object_content}

        break if response.token.nil?

        request = ContinueRetrievePropertiesExRequestType.new(@service_content.propertyCollector, response.token)
        response = @service.continueRetrievePropertiesEx(request).returnval
      end
      result
    end

  end

end