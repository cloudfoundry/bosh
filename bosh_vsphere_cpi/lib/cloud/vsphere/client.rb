module VSphereCloud
  class Client
    include VimSdk

    class TaskException < StandardError; end
    class FileNotFoundException < TaskException; end
    class DuplicateName < TaskException; end
    class AlreadyLoggedInException < StandardError; end
    class NotLoggedInException < StandardError; end

    attr_reader :cloud_searcher, :service_content, :service_instance, :soap_stub

    def initialize(host, options={})
      @soap_stub = SoapStub.new(host, options[:soap_log]).create

      @service_instance =Vim::ServiceInstance.new('ServiceInstance', @soap_stub)
      @service_content = @service_instance.content

      @metrics_cache  = {}
      @lock = Mutex.new
      @logger = options.fetch(:logger) { Bosh::Clouds::Config.logger }

      @cloud_searcher = CloudSearcher.new(service_content, @logger)
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

    def find_parent(obj, parent_type)
      while obj && obj.class != parent_type
        obj = @cloud_searcher.get_property(obj, obj.class, "parent", :ensure_all => true)
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

      raise 'Recommendations were detected, you may be running in Manual DRS mode. Aborting.' if result.recommendations.any?

      if result.attempted.empty?
        raise "Could not power on VM: #{result.not_attempted.map(&:msg).join(', ')}"
      else
        task = result.attempted.first.task
        wait_for_task(task)
      end
    end

    def power_off_vm(vm_mob)
      task = vm_mob.power_off
      wait_for_task(task)
    end

    def get_cdrom_device(vm)
      devices = @cloud_searcher.get_property(vm, Vim::VirtualMachine, 'config.hardware.device', ensure_all: true)
      devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualCdrom) }
    end

    def delete_path(datacenter, path)
      task = @service_content.file_manager.delete_file(path, datacenter)
      begin
        wait_for_task(task)
      rescue => e
        unless e.message =~ /File .* was not found/
          raise e
        end
      end
    end

    def delete_disk(datacenter, path)
      base_path = path.chomp(File.extname(path))
      [".vmdk", "-flat.vmdk"].each do |extension|
        delete_path(datacenter, "#{base_path}#{extension}")
      end
    end

    def move_disk(source_datacenter, source_path, dest_datacenter, dest_path)
      create_parent_folder(dest_datacenter, dest_path)
      tasks = []
      base_source_path = source_path.chomp(File.extname(source_path))
      base_dest_path = dest_path.chomp(File.extname(dest_path))
      [".vmdk", "-flat.vmdk"].each do |extension|
        tasks << @service_content.file_manager.move_file(
          "#{base_source_path}#{extension}", source_datacenter.mob,
          "#{base_dest_path}#{extension}", dest_datacenter.mob, false
        )
      end

      tasks.each { |task| wait_for_task(task) }
    end

    def create_datastore_folder(folder_path, datacenter)
      @service_content.file_manager.make_directory(folder_path, datacenter, true)
    end

    def create_folder(name)
      @service_content.root_folder.create_folder(name)
    end

    def move_into_folder(folder, objects)
      task = folder.move_into(objects)
      wait_for_task(task)
    end

    def move_into_root_folder(objects)
      task = @service_content.root_folder.move_into(objects)
      wait_for_task(task)
    end

    def delete_folder(folder)
      task = folder.destroy
      wait_for_task(task)
    end

    def find_by_inventory_path(path)
      full_path = Array(path).join("/")
      @service_content.search_index.find_by_inventory_path(full_path)
    end

    def wait_for_task(task)
      interval = 1.0
      started = Time.now
      loop do
        properties = @cloud_searcher.get_properties(
          [task],
          Vim::Task,
          ["info.progress", "info.state", "info.result", "info.error"],
          ensure: ["info.state"]
        )[task]

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
            raise task_exception_for_vim_fault(properties["info.error"])
        end
      end
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

    def find_disk(disk_cid, datastore, disk_folder)
      disk_path = "[#{datastore.name}] #{disk_folder}/#{disk_cid}.vmdk"
      disk_size_in_mb = find_disk_size_using_browser(datastore, disk_cid, disk_folder)
      disk_size_in_mb.nil? ? nil : Resources::Disk.new(disk_cid, disk_size_in_mb, datastore, disk_path)
    end

    def create_disk(datacenter, datastore, disk_cid, disk_folder, disk_size_in_mb)
      disk_path = "[#{datastore.name}] #{disk_folder}/#{disk_cid}.vmdk"

      create_parent_folder(datacenter, disk_path)

      disk_spec = VimSdk::Vim::VirtualDiskManager::FileBackedVirtualDiskSpec.new
      disk_spec.disk_type = 'preallocated'
      disk_spec.capacity_kb = disk_size_in_mb * 1024
      disk_spec.adapter_type = 'lsiLogic'

      task = service_content.virtual_disk_manager.create_virtual_disk(
        disk_path,
        datacenter.mob,
        disk_spec
      )
      wait_for_task(task)

      Resources::Disk.new(disk_cid, disk_size_in_mb, datastore, disk_path)
    end

    private

    def create_parent_folder(datacenter, disk_path)
      destination_folder = File.dirname(disk_path)
      create_datastore_folder(destination_folder, datacenter.mob)
    end

    def find_disk_size_using_browser(datastore, disk_cid, disk_folder)
      search_spec_details = VimSdk::Vim::Host::DatastoreBrowser::FileInfo::Details.new
      search_spec_details.file_type = true # actually return VmDiskInfos not FileInfos

      query_details = VimSdk::Vim::Host::DatastoreBrowser::VmDiskQuery::Details.new
      query_details.capacity_kb = true

      query = VimSdk::Vim::Host::DatastoreBrowser::VmDiskQuery.new
      query.details = query_details

      search_spec = VimSdk::Vim::Host::DatastoreBrowser::SearchSpec.new
      search_spec.details = search_spec_details
      search_spec.match_pattern = ["#{disk_cid}.vmdk"]
      search_spec.query = [query]

      vm_disk_infos = wait_for_task(datastore.mob.browser.search("[#{datastore.name}] #{disk_folder}", search_spec)).file
      return nil if vm_disk_infos.empty?

      vm_disk_infos.first.capacity_kb / 1024
    rescue VimSdk::SoapError, FileNotFoundException
      nil
    end

    def task_exception_for_vim_fault(fault)
      exceptions_by_fault = {
        VimSdk::Vim::Fault::FileNotFound => FileNotFoundException,
        VimSdk::Vim::Fault::DuplicateName => DuplicateName,
      }
      exceptions_by_fault.fetch(fault.class, TaskException).new(fault.msg)
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
