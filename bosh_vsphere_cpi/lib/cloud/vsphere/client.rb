require 'ruby_vim_sdk'

module VSphereCloud

  class Client
    include VimSdk
    PC = Vmodl::Query::PropertyCollector

    class AlreadyLoggedInException < StandardError; end
    class NotLoggedInException < StandardError; end

    attr_accessor :service_content
    attr_accessor :soap_stub
    attr_accessor :service_instance

    def initialize(host, options = {})
      http_client = HTTPClient.new
      log_path = options["soap_log"]
      if log_path
        log_file = File.open(log_path, "w")
        log_file.sync = true
        http_client.debug_dev = log_file
      end
      http_client.send_timeout = 14400
      http_client.receive_timeout = 14400
      http_client.connect_timeout = 4
      http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

      @soap_stub = Soap::StubAdapter.new(host, "vim.version.version6", http_client)

      @service_instance = Vim::ServiceInstance.new("ServiceInstance", soap_stub)
      @service_content = service_instance.content
      @metrics_cache  = {}
      @lock = Mutex.new
      @logger = Bosh::Clouds::Config.logger
    end

    def login(username, password, locale)
      raise AlreadyLoggedInException if @session
      @session = @service_content.session_manager.login(username, password, locale)
    end

    def logout
      raise NotLoggedInException unless @session
      @session = nil
      @service_content.session_manager.logout
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

      attempts = 0
      begin
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
            raise "The object[s] #{obj.pretty_inspect} " +
                      "should have the following properties: #{properties.pretty_inspect}, " +
                      "but they were missing these: #{remaining_properties.pretty_inspect}."
          end
          result[object_content.obj] = object_properties
        end

        result = result.values.first if obj.is_a?(Vmodl::ManagedObject)
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
      root = options[:root] || @service_content.root_folder
      property_specs = [PC::PropertySpec.new(:type => type, :all => false, :path_set => ["name"])]
      filter_spec = get_search_filter_spec(root, property_specs)
      object_specs = get_all_properties(filter_spec)

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

    def find_parent(obj, parent_type)
      while obj && obj.class != parent_type
        obj = get_property(obj, obj.class, "parent", :ensure_all => true)
      end
      obj
    end

    def reconfig_vm(vm, config)
      task = vm.reconfigure(config)
      wait_for_task(task)
    end

    def delete_vm(vm)
      task = vm.destroy
      wait_for_task(task)
    end

    def answer_vm(vm, question, answer)
      vm.answer(question, answer)
    end

    def power_on_vm(datacenter, vm)
      task = datacenter.power_on_vm([vm], nil)
      result = wait_for_task(task)

      raise "Recommendations were detected, you may be running in Manual DRS mode. Aborting." if result.recommendations.any?

      if result.attempted.empty?
        raise "Could not power on VM: #{result.not_attempted.map(&:msg).join(', ')}"
      else
        task = result.attempted.first.task
        wait_for_task(task)
      end
    end

    def power_off_vm(vm)
      task = vm.power_off
      wait_for_task(task)
    end

    def delete_path(datacenter, path)
      task = @service_content.file_manager.delete_file(path, datacenter)
      wait_for_task(task)
    end

    def delete_disk(datacenter, path)
      tasks = []
      [".vmdk", "-flat.vmdk"].each do |extension|
        tasks << @service_content.file_manager.delete_file("#{path}#{extension}", datacenter)
      end
      tasks.each { |task| wait_for_task(task) }
    end

    def move_disk(source_datacenter, source_path, dest_datacenter, dest_path)
      tasks = []
      [".vmdk", "-flat.vmdk"].each do |extension|
        tasks << @service_content.file_manager.move_file("#{source_path}#{extension}", source_datacenter,
                                                         "#{dest_path}#{extension}", dest_datacenter, false)
      end

      tasks.each { |task| wait_for_task(task) }
    end

    def copy_disk(source_datacenter, source_path, dest_datacenter, dest_path)
      tasks = []
      [".vmdk", "-flat.vmdk"].each do |extension|
        tasks << @service_content.file_manager.copy_file("#{source_path}#{extension}", source_datacenter,
                                                         "#{dest_path}#{extension}", dest_datacenter, false)
      end

      tasks.each { |task| wait_for_task(task) }
    end

    def find_by_inventory_path(path)
      full_path = Array(path).join("/")
      @service_content.search_index.find_by_inventory_path(full_path)
    end

    def wait_for_task(task)
      interval = 1.0
      started = Time.now
      loop do
        properties = get_properties([task], Vim::Task, ["info.progress", "info.state", "info.result", "info.error"],
                                    :ensure => ["info.state"])[task]

        duration = Time.now - started
        raise "Task taking too long" if duration > 3600 # 1 hour

        # Update the polling interval based on task progress
        if properties["info.progress"] && properties["info.progress"] > 0
          interval = ((duration * 100 / properties["info.progress"]) - duration) / 5
          if interval < 1
            interval = 1
          elsif interval > 10
            interval = 10
          elsif interval > duration
            interval = duration
          end
        end

        case properties["info.state"]
          when Vim::TaskInfo::State::RUNNING
            sleep(interval)
          when Vim::TaskInfo::State::QUEUED
            sleep(interval)
          when Vim::TaskInfo::State::SUCCESS
            return properties["info.result"]
          when Vim::TaskInfo::State::ERROR
            raise properties["info.error"].msg
        end
      end
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

    def get_perf_counters(mobs, names, options = {})
      metrics = find_perf_metric_names(mobs.first, names)
      metric_ids = metrics.values

      metric_name_by_id = {}
      metrics.each { |name, metric| metric_name_by_id[metric.counter_id] = name }

      queries = []
      mobs.each do |mob|
        queries << Vim::PerformanceManager::QuerySpec.new(
            :entity => mob,
            :metric_id => metric_ids,
            :format => Vim::PerformanceManager::Format::CSV,
            :interval_id => options[:interval_id] || 20,
            :max_sample => options[:max_sample])
      end

      query_perf_response = @service_content.perf_manager.query_stats(queries)

      result = {}
      query_perf_response.each do |mob_stats|
        mob_entry = {}
        counters = mob_stats.value
        counters.each do |counter_stats|
          counter_id = counter_stats.id.counter_id
          values = counter_stats.value
          mob_entry[metric_name_by_id[counter_id]] = values
        end
        result[mob_stats.entity] = mob_entry
      end
      result
    end

    def find_perf_metric_names(mob, names)
      @lock.synchronize do
        unless @metrics_cache.has_key?(mob.class)
          @metrics_cache[mob.class] = fetch_perf_metric_names(mob)
        end
      end

      result = {}
      @metrics_cache[mob.class].each do |name, metric|
        result[name] = metric if names.include?(name)
      end

      result
    end

    def fetch_perf_metric_names(mob)
      metrics = @service_content.perf_manager.query_available_metric(mob, nil, nil, 300)
      metric_ids = metrics.collect { |metric| metric.counter_id }

      metric_names = {}
      metrics_info = @service_content.perf_manager.query_counter(metric_ids)
      metrics_info.each do |perf_counter_info|
        name = "#{perf_counter_info.group_info.key}.#{perf_counter_info.name_info.key}.#{perf_counter_info.rollup_type}"
        metric_names[perf_counter_info.key] = name
      end

      result = {}
      metrics.each { |metric| result[metric_names[metric.counter_id]] = metric }
      result
    end
  end

end
