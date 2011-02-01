module VSphereCloud

  class Client

    class AlreadyLoggedInException < StandardError; end
    class NotLoggedInException < StandardError; end

    attr_accessor :service_content
    attr_accessor :service

    def initialize(host, options = {})
      @service                                                 = VimPortType.new(host)
      @service.options["protocol.http.ssl_config.verify_mode"] = OpenSSL::SSL::VERIFY_NONE
      if options["soap_log"]
        log_file = File.open(options["soap_log"], "w")
        log_file.sync = true
        @service.wiredump_dev = log_file
      end

      service_ref                      = ManagedObjectReference.new("ServiceInstance")
      service_ref.xmlattr_type         = "ServiceInstance"

      retrieve_service_content_request = RetrieveServiceContentRequestType.new(service_ref)
      @service_content                 = @service.retrieveServiceContent(retrieve_service_content_request).returnval
      @metrics_cache                   = {}
      @lock                            = Mutex.new
      @logger                          = Bosh::Director::Config.logger
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

    def get_properties(obj, type, properties, options = {})
      property_specs = [PropertySpec.new(nil, nil, type, false, properties)]

      if obj.is_a?(ManagedObjectReference)
        object_spec = ObjectSpec.new(nil, nil, obj, false)
      else
        object_spec = obj.collect {|o| ObjectSpec.new(nil, nil, o, false)}
      end

      filter_spec = PropertyFilterSpec.new(nil, nil, property_specs, object_spec)
      properties_request = RetrievePropertiesExRequestType.new(@service_content.propertyCollector, filter_spec,
                                                               RetrieveOptions.new)

      # TODO: cache partial results
      attempts = 0
      begin
        properties_response = get_all_properties(properties_request)
        result = {}

        properties_response.each do |object_content|
          object_properties = {:obj => object_content.obj}
          if options[:ensure_all]
            remaining_properties = Set.new(properties)
          else
            remaining_properties = Set.new(options[:ensure])
          end
          if object_content.propSet
            object_content.propSet.each do |property|
              object_properties[property.name] = property.val
              remaining_properties.delete(property.name)
            end
          end
          unless remaining_properties.empty?
            raise "The object[s] #{obj.pretty_inspect} " +
                      "should have the following properties: #{properties.pretty_inspect}, " +
                      "but they were missing these: #{remaining_properties.pretty_inspect}."
          end
          result[object_content.obj] = object_properties
        end

        result = result.values[0] if obj.is_a?(String)
        result
      rescue => e
        attempts += 1
        if attempts < 8
          sleep_interval = 2 ** attempts
          @logger.warn("Error retrieving properties, retrying in #{sleep_interval} seconds: " +
                       "#{e} - #{e.backtrace.join("\n")}")
          sleep(sleep_interval)
          retry
        else
          raise e
        end
      end
    end

    def get_property(obj, type, property, options = {})
      get_properties(obj, type, property, options)[property]
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

    def find_parent(obj, parent_type)
      loop do
        obj = get_property(obj, obj.xmlattr_type, "parent", :ensure_all => true)
        break if obj.nil? || obj.xmlattr_type == parent_type
      end
      obj
    end

    def reconfig_vm(vm, config)
      request = ReconfigVMRequestType.new(vm)
      request.spec = config

      task = @service.reconfigVM_Task(request).returnval
      wait_for_task(task)
    end

    def delete_vm(vm)
      task = @service.destroy_Task(DestroyRequestType.new(vm)).returnval
      wait_for_task(task)
    end

    def answer_vm(vm, question, answer)
      request = AnswerVMRequestType.new(vm)
      request.questionId = question
      request.answerChoice = answer
      @service.answerVM(request)
    end

    def power_on_vm(datacenter, vm)
      request = PowerOnMultiVMRequestType.new(datacenter, [vm])
      task = @service.powerOnMultiVM_Task(request).returnval
      result = wait_for_task(task)
      if result.attempted.nil?
        raise "Could not power on VM: #{result.notAttempted.localizedMessage}"
      else
        task = result.attempted.first.task
        wait_for_task(task)
      end
    end

    def power_off_vm(vm)
      request = PowerOffVMRequestType.new(vm)
      task = @service.powerOffVM_Task(request).returnval
      wait_for_task(task)
    end

    def delete_disk(datacenter, path)
      request = DeleteDatastoreFileRequestType.new(@service_content.fileManager)
      request.name = path
      request.datacenter = datacenter
      task = @service.deleteDatastoreFile_Task(request).returnval
      wait_for_task(task)
    end

    def move_disk(source_datacenter, source_path, destination_datacenter, destination_path)
      request = MoveDatastoreFileRequestType.new(@service_content.fileManager)
      request.sourceName = source_path
      request.sourceDatacenter = source_datacenter
      request.destinationName = destination_path
      request.destinationDatacenter = destination_datacenter
      task = @service.moveDatastoreFile_Task(request).returnval
      wait_for_task(task)
    end

    def find_by_inventory_path(path)
      path = [path] unless path.kind_of?(Array)
      path = path.flatten.collect {|name| name.gsub("/", "%2f")}.join("/")
      find_request = FindByInventoryPathRequestType.new(@service_content.searchIndex, path)
      @service.findByInventoryPath(find_request).returnval
    end

    def wait_for_task(task, options = {})
      interval = options[:interval] || 1.0
      loop do
        properties = get_properties([task], "Task",
                                    ["info.progress", "info.state",
                                     "info.result", "info.error"], :ensure => ["info.state"])[task]
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

    def get_perf_counters(mobs, names, options = {})
      metrics           = find_perf_metric_names(mobs.first, names)
      metric_ids        = metrics.values

      metric_name_by_id = {}
      metrics.each { |name, metric| metric_name_by_id[metric.counterId] = name }

      queries    = []
      mobs.each do |mob|
        query            = PerfQuerySpec.new
        query.entity     = mob
        query.metricId   = metric_ids
        query.format     = PerfFormat::Csv
        query.intervalId = options[:interval_id] || 20
        query.maxSample  = options[:max_sample]
        queries << query
      end

      query_perf_request  = QueryPerfRequestType.new(service_content.perfManager, queries)
      # TODO: shard and send requests in parallel for better performance
      query_perf_response = service.queryPerf(query_perf_request)

      result = {}
      query_perf_response.each do |mob_stats|
        mob_entry = {}
        counters  = mob_stats.value
        counters.each do |counter_stats|
          counter_id = counter_stats.id.counterId
          values     = counter_stats.value
          mob_entry[metric_name_by_id[counter_id]] = values
        end
        result[mob_stats.entity] = mob_entry
      end
      result
    end

    def find_perf_metric_names(mob, names)
      type = mob.xmlattr_type
      @lock.synchronize do
        unless @metrics_cache.has_key?(type)
          @metrics_cache[type] = fetch_perf_metric_names(mob)
        end
      end

      result = {}
      @metrics_cache[type].each do |name, metric|
        result[name] = metric if names.include?(name)
      end

      result
    end

    def fetch_perf_metric_names(mob)
      request            = QueryAvailablePerfMetricRequestType.new(service_content.perfManager, mob)
      request.intervalId = 300
      metrics            = service.queryAvailablePerfMetric(request)

      metric_ids         = metrics.collect { |metric| metric.counterId }
      request            = QueryPerfCounterRequestType.new(service_content.perfManager, metric_ids)
      metrics_info       = service.queryPerfCounter(request)

      metric_names       = {}
      metrics_info.each do |perf_counter_info|
        name = "#{perf_counter_info.groupInfo.key}.#{perf_counter_info.nameInfo.key}.#{perf_counter_info.rollupType}"
        metric_names[perf_counter_info.key] = name
      end

      result = {}
      metrics.each { |metric| result[metric_names[metric.counterId]] = metric }
      result
    end
  end

end