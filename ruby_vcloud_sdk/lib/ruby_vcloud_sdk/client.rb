require "rest_client" # Need this for the exception classes
require "set"

module VCloudSdk

  class Client
    attr_reader :ovdc

    def initialize(url, username, password, entities, control,
        connection = nil)
      @logger = Config.logger
      @url = url
      @organization = entities["organization"]
      @ovdc_name = entities["virtual_datacenter"]
      @vapp_catalog_name = entities["vapp_catalog"]
      @media_catalog_name = entities["media_catalog"]
      @control = control
      @retries = @control["retries"]
      @time_limit = @control["time_limit_sec"]
      construct_rest_logger
      Config.configure({ "rest_logger" => @rest_logger,
        "rest_throttle" => control["rest_throttle"] })

      if connection
        @connection = connection
      else
        @connection = Connection::Connection.new(@url, @organization,
          @time_limit["http_request"])
      end
      @root = @connection.connect(username, password)
      @admin_root = @connection.get(@root.admin_root)
      @entity_resolver_link = @root.entity_resolver.href
      # We assume the organization does not change often so we can get it at
      # login and cache it
      @admin_org = @connection.get(@admin_root.organization(@organization))
      @logger.info("Successfully connected.")
    end

    def get_catalog_vapp(id)
      resolve_entity(id)
    end

    def get_vapp(obj)
      if obj.is_a?(Xml::VApp)
        obj
      elsif obj.is_a?(String)
        resolve_entity(obj)
      else
        raise CloudError, "Expecting Xml::VApp or String, got #{obj.inspect}."
      end
    end

    def upload_vapp_template(vapp_name, directory)
      ovdc = get_ovdc
      @logger.info("Uploading VM #{vapp_name} to #{ovdc["name"]} in " +
                   "organization #{@organization}")
      # if directory behaves like an OVFDirectory, then use it
      is_ovf_directory = [:ovf_file, :ovf_file_path, :vmdk_file,
          :vmdk_file_path].reduce(true) do |present, name|
        present && directory.respond_to?(name)
      end
      ovf_directory = is_ovf_directory ? directory :
        OVFDirectory.new(directory)
      upload_params = Xml::WrapperFactory.create_instance(
        "UploadVAppTemplateParams")
      upload_params.name = vapp_name
      vapp_template = @connection.post(ovdc.upload_link, upload_params)
      catalog_name = @vapp_catalog_name
      vapp_template = upload_vapp_files(vapp_template, ovf_directory)
      raise ObjectNotFoundError, "Error uploading vApp template" unless
        vapp_template
      @logger.info("#{vapp_template.name} has tasks in progress.  " +
                   "Waiting until done.")
      vapp_template.running_tasks.each do |task|
        monitor_task(task, @time_limit["process_descriptor_vapp_template"])
      end
      err_tasks = @connection.get(vapp_template).tasks.find_all {
        |t| t.status != Xml::TASK_STATUS[:SUCCESS] }
      unless err_tasks.empty?
        @logger.error("Error uploading vApp template.  " +
                      "Non-successful tasks:#{err_tasks}.")
        raise CloudError, "Error uploading vApp template"
      end
      @logger.info("vApp #{vapp_name} uploaded, adding to " +
                   "catalog #{catalog_name}")
      catalog_item = add_catalog_item(vapp_template, catalog_name)
      @logger.info("vApp #{vapp_name} added to catalog " +
                   "#{catalog_name} #{catalog_item.to_s}")
      catalog_item
    rescue ApiError => e
      log_exception(e, "Error in uploading vApp template #{vapp_name}")
      rollback_upload_vapp(vapp_template)
      raise e
    end

    def insert_catalog_media(vm, catalog_media_name)
      catalog_media = get_catalog_media(catalog_media_name)
      media = @connection.get(catalog_media.entity)
      current_vm = @connection.get(vm)
      insert_media(current_vm, media)
    end

    def eject_catalog_media(vm, catalog_media_name)
      catalog_media = get_catalog_media(catalog_media_name)
      unless catalog_media
        raise CatalogMediaNotFoundError,
          "Catalog media #{catalog_media_name} not found."
      end
      media = @connection.get(catalog_media.entity)
      current_vm = @connection.get(vm)
      eject_media(current_vm, media)
    end

    def upload_catalog_media(media_name, file, storage_profile = nil,
        image_type = "iso")
      ovdc = get_ovdc
      @logger.info("Uploading media #{media_name} to #{storage_profile}/" +
                   "#{ovdc["name"]} in organization #{@organization}")
      catalog_name = @media_catalog_name
      upload_params = Xml::WrapperFactory.create_instance("Media")
      upload_params.name = media_name
      media_file = file.is_a?(String) ? File.new(file, "rb") : file
      upload_params.size = media_file.stat.size
      upload_params.image_type = image_type
      upload_params.storage_profile = storage_profile
      media = @connection.post(ovdc.upload_media_link, upload_params)
      incomplete_file = media.incomplete_files.pop
      @connection.put_file(incomplete_file.upload_link, media_file)
      media = @connection.get(media)
      add_catalog_item(media, catalog_name)
    rescue ArgumentError, ApiError => e
      log_exception(e, "Error uploading media #{media_name}" +
                  "to catalog #{catalog_name}. #{e.message}")
      delete_media(media) if media
      raise e
    end

    def delete_catalog_media(name)
      raise ArgumentError, "Media name cannot be nil." unless name
      catalog_media = get_catalog_media(name)
      if catalog_media
        media = @connection.get(catalog_media.entity)
        delete_media(media)
        @connection.delete(catalog_media)
      end
    rescue RestClient::ResourceNotFound => e
      # Media might be deleted already
      @logger.debug("Catalog media #{name} no longer exists.")
    end

    def delete_catalog_vapp(id)
      raise ArgumentError, "Catalog ID cannot be nil." unless id
      catalog_vapp = get_catalog_vapp(id)
      if catalog_vapp
        vapp = @connection.get(catalog_vapp.entity)
        delete_vapp_template(vapp)
        @connection.delete(catalog_vapp)
      end
    rescue => e
      # vApp template might be deleted already
      @logger.debug("Catalog vApp #{id} no longer exists.")
    end

    def delete_vapp(vapp)
      @logger.info("Deleting vApp #{vapp.name}.")
      current_vapp = @connection.get(vapp)
      if is_vapp_status(current_vapp, :POWERED_ON)
        raise CloudError,
          "vApp #{vapp.name} is powered on, power-off before deleting."
      end
      delete_vapp_or_template(current_vapp, @retries["default"],
        @time_limit["delete_vapp"], "vApp")
    end

    def instantiate_vapp_template(source_template_id, vapp_name,
        description = nil, disk_locality = nil)
      catalog_item = get_catalog_vapp(source_template_id)
      unless catalog_item
        @logger.error("Catalog item with ID #{source_template_id} not " +
                    "found in catalog #{@vapp_catalog_name}.")
        raise ObjectNotFoundError, "Item with ID #{source_template_id} " +
            "not found in catalog #{@vapp_catalog_name}."
      end
      src_vapp_template = @connection.get(catalog_item.entity)
      instantiate_vapp_params = Xml::WrapperFactory.create_instance(
        "InstantiateVAppTemplateParams")
      instantiate_vapp_params.name = vapp_name
      instantiate_vapp_params.description = description
      instantiate_vapp_params.source = src_vapp_template
      instantiate_vapp_params.all_eulas_accepted = true
      instantiate_vapp_params.linked_clone = false
      instantiate_vapp_params.set_locality = locality_spec(src_vapp_template,
        disk_locality)
      vdc = get_ovdc
      vapp = @connection.post(vdc.instantiate_vapp_template_link,
        instantiate_vapp_params)
      vapp.running_tasks.each do |task|
        begin
          monitor_task(task, @time_limit["instantiate_vapp_template"])
        rescue ApiError => e
          log_exception(e, "Instantiate vApp template #{vapp_name} failed." +
            "  Task #{task.operation} did not complete successfully.")
          delete_vapp(vapp)
          raise e
        end
      end
      @connection.get(vapp)
    end

    def reconfigure_vm(vm, &b)
      b.call(vm)
      monitor_task(@connection.post("#{vm.reconfigure_link.href}", vm,
        Xml::MEDIA_TYPE[:VM]))
    end

    def get_metadata(entity, key)
      metadata = @connection.get(generate_metadata_href(entity, key))
      metadata.value
    end

    def set_metadata(entity, key, value)
      metadata = Xml::WrapperFactory.create_instance("MetadataValue")
      metadata.value = value
      task = @connection.put(generate_metadata_href(entity, key), metadata,
        Xml::MEDIA_TYPE[:METADATA_ITEM_VALUE])
      monitor_task(task)
    end

    def delete_networks(vapp, exclude_nets = [])
      current_vapp = get_vapp(vapp)
      raise ObjectNotFoundError, "Cannot delete nets, vApp #{vapp.name} no " +
        "longer exists" unless current_vapp
      current = current_vapp.network_config_section.network_configs.map {
        |n| n.network_name }
      nets = current - exclude_nets
      @logger.debug("nets:: current:#{current}, exclude:#{exclude_nets}, " +
                    "to delete:#{nets}")
      return if nets.nil? || nets.length == 0
      delete_network(current_vapp, *nets)
    end

    def add_network(vapp, network, vapp_net_name = nil,
       fence_mode = Xml::FENCE_MODES[:BRIDGED])
      current_network = @connection.get(network)
      raise ObjectNotFoundError, "Cannot add network to vApp #{vapp.name}. " +
        "The network #{network.name} no longer exists." unless current_network
      current_vapp = get_vapp(vapp)
      raise ObjectNotFoundError, "Cannot add network to vApp #{vapp.name}. " +
        "The vApp #{vapp.name} no longer exists." unless current_vapp
      network_config = Xml::WrapperFactory.create_instance("NetworkConfig")
      new_vapp_net_name = vapp_net_name.nil? ?
        current_network["name"] : vapp_net_name
      copy_network_settings(current_network, network_config,
        new_vapp_net_name, fence_mode)
      current_vapp.network_config_section.add_network_config(network_config)
      task = @connection.put(current_vapp.network_config_section,
        current_vapp.network_config_section,
        Xml::MEDIA_TYPE[:NETWORK_CONFIG_SECTION])
      monitor_task(task)
    end

    # There must be no NICs on the network when it is deleted.  Otherwise the
    # task will fail.  Use set_nic_network to move NICs onto other network or
    # the NONE network prior to deleting the network from the vApp.
    def delete_network(vapp, *network_names)
      raise ArgumentError, "Must specify a network name to delete." if
        network_names.nil? || network_names.length == 0
      unique_network_names = network_names.uniq
      @logger.info("Delete networks(s) #{unique_network_names.join(" ")} " +
                   "from vApp #{vapp.name}")
      current_vapp = get_vapp(vapp)
      unique_network_names.each do |n|
        current_vapp.network_config_section.delete_network_config(n)
      end
      task = @connection.put(current_vapp.network_config_section,
        current_vapp.network_config_section,
        Xml::MEDIA_TYPE[:NETWORK_CONFIG_SECTION])
      monitor_task(task)
    end

    # Size at creation is in bytes
    # We currently assumes the disk is SCSI and bus sub type LSILOGIC
    def create_disk(name, size_mb, vm = nil, retries = @retries["default"])
      new_disk = Xml::WrapperFactory.create_instance("DiskCreateParams")
      new_disk.name = name
      new_disk.size_bytes = size_mb * 1024 * 1024 # VCD expects bytes
      new_disk.bus_type = Xml::HARDWARE_TYPE[:SCSI_CONTROLLER]
      new_disk.bus_sub_type = Xml::BUS_SUB_TYPE[:LSILOGIC]
      new_disk.add_locality(vm) if vm
      vdc = get_ovdc
      @logger.info("Creating independent disk #{name} of #{size_mb}MB.")
      @logger.info("Disk locality ist set to #{vm.name} #{vm.urn}.") if vm
      disk = @connection.post(vdc.add_disk_link, new_disk,
        Xml::MEDIA_TYPE[:DISK_CREATE_PARAMS])
      raise ApiRequestError unless disk.respond_to?(:running_tasks)
      # Creating a disk returns a disk with tasks inside
      retries.times do |try|
        return disk if disk.running_tasks.nil? || disk.running_tasks.empty?
        @logger.info("Disk #{disk.urn} has running tasks.  Waiting for " +
                     "tasks to finish.  Try: #{try}/#{retries} ." )
        disk.running_tasks.each do |t|
          monitor_task(t)
        end
        disk = @connection.get(disk)
      end
    end

    def delete_disk(disk)
      current_disk = @connection.get(disk)
      unless current_disk
        @logger.warn("Disk #{disk.name} #{disk.urn} no longer exists.")
        return
      end
      task = @connection.delete(current_disk.delete_link)
      monitor_task(task) do |t|
        @logger.info("Deleted disk #{current_disk.name} #{current_disk.urn}")
        t
      end
    end

    def attach_disk(disk, vm)
      current_vm = @connection.get(vm)
      raise ObjectNotFoundError, "VM #{vm.name} not found." unless current_vm

      current_disk = @connection.get(disk)
      unless current_disk
        raise ObjectNotFoundError, "Disk #{disk.name} not found."
      end

      params = Xml::WrapperFactory.create_instance("DiskAttachOrDetachParams")
      params.disk_href = current_disk.href
      task = @connection.post(current_vm.attach_disk_link, params,
        Xml::MEDIA_TYPE[:DISK_ATTACH_DETACH_PARAMS])
      monitor_task(task) do |t|
        @logger.info("Attached disk #{current_disk.name} to VM " +
                     "#{current_vm.name}.")
        t
      end
    end

    def detach_disk(disk, vm)
      current_vm = @connection.get(vm)
      raise ObjectNotFoundError, "VM #{vm.name} not found." unless current_vm

      current_disk = @connection.get(disk)
      unless current_disk
        raise ObjectNotFoundError, "Disk #{disk.name} not found."
      end

      disk_href = current_disk.href

      if is_vapp_status(current_vm, :SUSPENDED)
        @logger.debug("vApp #{current_vm.name} suspended, discard state " +
                      "before detaching disk.")
        raise VmSuspendedError, "discard state first"
      end

      begin
        get_disk_id(current_vm, disk_href)
      rescue DiskNotFoundError
        @logger.warn("Disk #{current_disk.name} not found on VM " +
                     "#{current_vm.name}.  No need to detach.")
        return
      end
      params = Xml::WrapperFactory.create_instance("DiskAttachOrDetachParams")
      params.disk_href = disk_href
      task = @connection.post(current_vm.detach_disk_link, params,
        Xml::MEDIA_TYPE[:DISK_ATTACH_DETACH_PARAMS])
      monitor_task(task) do |t|
        @logger.info("Detached disk #{current_disk.name} from VM " +
                     "#{current_vm.name}.")
        t
      end
    end

    def get_disk(disk_id)
      resolve_entity(disk_id)
    end

    def power_on_vapp(vapp)
      @logger.info("Powering on vApp #{vapp.name} .")
      current_vapp = @connection.get(vapp)
      unless current_vapp
        raise ObjectNotFoundError, "vApp #{vapp.name} not found."
      end
      @logger.debug("vApp status: #{current_vapp["status"]}")
      if is_vapp_status(current_vapp, :POWERED_ON)
        @logger.info("vApp #{vapp.name} already powered-on.")
        return
      end
      unless current_vapp.power_on_link
        raise CloudError, "vApp #{vapp.name} not in a state to be " +
          "powered on."
      end
      task = @connection.post(current_vapp.power_on_link, nil)
      monitor_task(task,  @time_limit["power_on"])
      @logger.info("vApp #{current_vapp.name} powered on.")
      task
    end

    def power_off_vapp(vapp, undeploy = true)
      @logger.info("Powering off vApp #{vapp.name} .")
      @logger.info("Undeploying vApp #{vapp.name} .") if undeploy
      current_vapp = @connection.get(vapp)
      unless current_vapp
        raise ObjectNotFoundError, "vApp #{vapp.name} no longer exists."
      end
      @logger.debug("vApp status: #{current_vapp["status"]}")

      if is_vapp_status(current_vapp, :SUSPENDED)
        @logger.debug("vApp #{current_vapp.name} suspended, discard state " +
                      "before powering off.")
        raise VappSuspendedError, "discard state first"
      end

      if undeploy
        # Since we do not apparently differentiate between powered-off and
        # undeployed in our status, we should check if the undeploy link is
        # available first.  If undeploy is not available and status is
        # powered_off then it is undeployed.
        unless current_vapp.undeploy_link
          if is_vapp_status(current_vapp, :POWERED_OFF)
            @logger.info("vApp #{vapp.name} already powered-off, undeployed.")
            return
          end
          raise CloudError, "vApp #{vapp.name} not in a state be " +
            "powered-off, undeployed."
        end
        params = Xml::WrapperFactory.create_instance("UndeployVAppParams")
        task = @connection.post(current_vapp.undeploy_link, params)
        monitor_task(task, @time_limit["undeploy"])
        @logger.info("vApp #{current_vapp.name} powered-off, undeployed.")
        task
      else
        unless current_vapp.power_off_link
          if is_vapp_status(current_vapp, :POWERED_OFF)
            @logger.info("vApp #{vapp.name} already powered off.")
            return
          end
          raise CloudError, "vApp #{vapp.name} not in a state be powered off."
        end
        task = @connection.post(current_vapp.power_off_link, nil)
        monitor_task(task, @time_limit["power_off"])
        @logger.info("vApp #{current_vapp.name} powered off.")
        task
      end
    end

    def discard_suspended_state_vapp(vapp)
      @logger.info("Discarding suspended state of vApp #{vapp.name}.")
      current_vapp = @connection.get(vapp)
      unless current_vapp
        raise ObjectNotFoundError, "vApp #{vapp.name} no longer exists."
      end
      @logger.debug("vApp status: #{current_vapp["status"]}")

      return unless is_vapp_status(current_vapp, :SUSPENDED)

      @logger.info("Discarding suspended state of vApp #{current_vapp.name}.")
      task = @connection.post(current_vapp.discard_state, nil)
      monitor_task(task, @time_limit["undeploy"])
      current_vapp = @connection.get(current_vapp)
      @logger.info("vApp #{current_vapp.name} suspended state discarded.")
      task
    end

    def reboot_vapp(vapp)
      @logger.info("Rebooting vApp #{vapp.name}.")
      current_vapp = @connection.get(vapp)
      unless current_vapp
        raise ObjectNotFoundError, "vApp #{vapp.name} no longer exists."
      end
      @logger.debug("vApp status: #{current_vapp["status"]}")

      if is_vapp_status(current_vapp, :SUSPENDED)
        @logger.debug("vApp #{current_vapp.name} suspended.")
        raise VappSuspendedError, "vapp suspended"
      end
      if is_vapp_status(current_vapp, :POWERED_OFF)
        @logger.debug("vApp #{current_vapp.name} powered off.")
        raise VappPoweredOffError, "vapp powered off"
      end

      @logger.info("Rebooting vApp #{current_vapp.name}.")
      task = @connection.post(current_vapp.reboot_link, nil)
      monitor_task(task)
      current_vapp = @connection.get(current_vapp)
      @logger.info("vApp #{current_vapp.name} rebooted.")
      task
    end

    def get_ovdc
      vdc = @admin_org.vdc(@ovdc_name)
      raise ObjectNotFoundError, "VDC #{@ovdc_name} not found." unless vdc
      @connection.get(vdc)
    end

    def get_catalog(name)
      catalog = @connection.get(@admin_org.catalog(name))
    end

    private

    ERROR_STATUSES = [Xml::TASK_STATUS[:ABORTED], Xml::TASK_STATUS[:ERROR],
      Xml::TASK_STATUS[:CANCELED]]
    SUCCESS_STATUS = [Xml::TASK_STATUS[:SUCCESS]]

    def resolve_entity(id)
      url = "#{@entity_resolver_link}#{id}"
      entity = @connection.get(url)
      raise ObjectNotFoundError, "Unable to get entity" unless entity
      @connection.get(entity.link)
    end

    def get_disk_id(vm, disk_href)
      hardware_section = vm.hardware_section
      disk = hardware_section.hard_disks.find do |d|
        d.host_resource["disk"] == disk_href
      end
      unless disk
        raise DiskNotFoundError, "Disk with href #{disk_href} not attached " +
                               "to VM #{vm.name}."
      end
      disk.disk_id
    end

    def log_exception(e, message = nil)
      @logger.error(message) if message
      @logger.error(e.message)
      @logger.error(e.backtrace.join("\n\r"))
    end

    def copy_network_settings(network, network_config, vapp_net_name,
        fence_mode)
      config_ip_scope = network_config.ip_scope
      net_ip_scope = network.ip_scope
      config_ip_scope.is_inherited = net_ip_scope.is_inherited?
      config_ip_scope.gateway= net_ip_scope.gateway
      config_ip_scope.netmask = net_ip_scope.netmask
      if net_ip_scope.start_address
        config_ip_scope.start_address = net_ip_scope.start_address
      end
      if net_ip_scope.end_address
        config_ip_scope.end_address = net_ip_scope.end_address
      end
      network_config.fence_mode = fence_mode
      network_config.parent_network["name"] = network["name"]
      network_config.parent_network["href"] = network["href"]
      network_config["networkName"] = vapp_net_name
    end

    def delete_vapp_template(vapp_template)
      delete_vapp_or_template(vapp_template, @retries["default"],
        @time_limit["delete_vapp_template"], "vApp Template")
    end

    def check_vapp_for_remove_link(vapp)
      current_vapp = @connection.get(vapp)
      unless current_vapp.remove_link
        raise ObjectNotFoundError, "No link available to delete vApp."
      end
      return current_vapp
    end

    def delete_vapp_or_template(vapp, retries, time_limit, type_name)
      retries.times do |try|
        @logger.info("Deleting #{type_name} #{vapp.name}")
        current_vapp = @connection.get(vapp)
        if (current_vapp.running_tasks.empty?)
          Util.retry_operation(current_vapp, @retries["default"],
            @control["backoff"]) do
            current_vapp = check_vapp_for_remove_link(current_vapp)
          end
          Util.retry_operation(current_vapp.remove_link, @retries["default"],
              @control["backoff"]) do
            monitor_task(@connection.delete(current_vapp.remove_link),
                time_limit) do |task|
              @logger.info("#{type_name} #{current_vapp.name} deleted.")
              return task
            end
          end
        else
          @logger.info("#{vapp.name} has tasks in progress, wait until done.")
          current_vapp.running_tasks.each do |task|
            monitor_task(task)
          end
          sleep (@control["backoff"] ** try)
        end
      end
      raise ApiRequestError,
        "Unable to delete #{type_name} after #{retries} attempts"
    end

    def insert_media(vm, media, retries = @retries["default"])
      params = Xml::WrapperFactory.create_instance("MediaInsertOrEjectParams")
      params.media_href = media.href

      # Wait for media to be ready
      retries.times do |try|
        @logger.info("Inserting media #{media.name} into VM #{vm.name}.")
        current_media = @connection.get(media)
        if (current_media.running_tasks.empty?)
          Util.retry_operation(vm.insert_media_link, @retries["default"],
              @control["backoff"]) do
            task = @connection.post(vm.insert_media_link, params,
              Xml::MEDIA_TYPE[:MEDIA_INSERT_EJECT_PARAMS])
            monitor_task(task) do |t|
              raise CloudError, "Error inserting media #{media.name} " +
                    "into VM #{vm.name}." if t.status != "success"
              @logger.info("Inserted media #{media.name} into VM #{vm.name}.")
              return t
            end
          end
        else
          @logger.info("#{current_media.name} has tasks in progress, " +
                       "waiting until done.")
          current_media.running_tasks.each do |task|
            monitor_task(task)
          end
          sleep (@control["backoff"] ** try)
        end
      end
      raise ApiRequestError, "Unable to insert media #{media.name} into " +
                             "VM #{vm.name} after #{retries} attempts"
    end

    def eject_media(vm, media, retries = @retries["default"])
      params = Xml::WrapperFactory.create_instance("MediaInsertOrEjectParams")
      params.media_href = media.href

      #Wait for media to be ready
      retries.times do |try|
        @logger.info("Ejecting media #{media.name} from VM #{vm.name}.")
        current_media = @connection.get(media)
        if (current_media.running_tasks.empty?)
          return eject_media_task(vm, params, media)
        else
          @logger.info("#{current_media.name} has tasks in progress, " +
                       "waiting until done.")
          current_media.running_tasks.each do |task|
            monitor_task(task)
          end
          sleep (@control["backoff"] ** try)
        end
      end
      raise ApiRequestError, "Unable to eject media #{media.name} from " +
                             "VM #{vm.name} after #{retries} attempts"
    end

    def delete_media(media, retries = @retries["default"],
        time_limit = @time_limit["delete_media"])
      retries.times do |try|
        @logger.info("Deleting media #{media.name}")
        current_media = @connection.get(media)
        if (current_media.running_tasks.empty?)
          Util.retry_operation(current_media.delete_link, @retries["default"],
              @control["backoff"]) do
            monitor_task(@connection.delete(current_media.delete_link),
                time_limit) do |task|
              @logger.info("Media #{current_media.name} deleted.")
              return task
            end
          end
        else
          @logger.info("#{current_media.name} has tasks in progress, " +
                       "waiting until done.")
          current_media.running_tasks.each do |task|
            monitor_task(task)
          end
          sleep (@control["backoff"] ** try)
        end
      end
      raise ApiRequestError, "Unable to delete #{type_name} after "
                             "#{retries} attempts"
    end

    def get_catalog_media(name)
      get_catalog_item(name, Xml::MEDIA_TYPE[:MEDIA], @media_catalog_name)
    end

    # Get catalog item from catalog by name and type.
    # Raises an exception if catalog is not found.
    # Returns nil if an item matching the name and type is not found.
    # Otherwise, returns the catalog item.
    # The catalog item is not the uderlying object itself, i.e. vApp template.
    def get_catalog_item(name, item_type, catalog_name)
      raise ObjectNotFoundError, "Catalog item name cannot be nil" unless name
      unless @admin_org.catalog(catalog_name)
        raise ObjectNotFoundError, "Catalog #{catalog_name} not found."
      end
      # For some reason, if the catalog no longer exists,
      # VCD throws a Forbidden exception when getting
      catalog = @connection.get(@admin_org.catalog(catalog_name))
      items = catalog.catalog_items(name)
      if items.nil? || items.empty?
        @logger.debug("Item #{name} does not exist in catalog #{catalog_name}")
        return nil
      end
      items.each do |i|
        entity = @connection.get(i)
        # Return the entity node.  Another get on that node is necessary to
        # get the actual object itself
        return entity if entity.entity["type"] == item_type
      end
      nil
    end

    def get_vm_network_connections(vm)
      current_vm = @connection.get(vm)
      unless current_vm
        raise ObjectNotFoundError, "VM #{vm.name} no longer exists."
      end
      @connection.get(current_vm.network_connection_section)
    end

    def task_progressed?(current_task, prev_progress, prev_status)
      (current_task.progress && (current_task.progress != prev_progress)) ||
        (current_task.status && (current_task.status != prev_status))
    end

    def task_is_success(current_task, success = SUCCESS_STATUS)
      success.map { |s| s.downcase }.find {
        |s| s == current_task.status.downcase }
    end

    def task_has_error(current_task, error_statuses = ERROR_STATUSES)
      error_statuses.map { |s| s.downcase }.find {
        |s| s == current_task.status.downcase }
    end

    def monitor_task(task, time_limit = @time_limit["default"],
        error_statuses = ERROR_STATUSES, success = SUCCESS_STATUS,
        delay = @control["delay"], &b)
      iterations = time_limit / delay
      i = 0
      prev_progress = task.progress
      prev_status = task.status
      current_task = task
      while (i < iterations)
        @logger.debug("#{current_task.urn} #{current_task.operation} is " +
                      "#{current_task.status}")
        if task_is_success(current_task, success)
          if b
            return b.call(current_task)
          else
            return current_task
          end
        elsif task_has_error(current_task, error_statuses)
          raise ApiRequestError, "Task #{task.urn} #{task.operation} did " +
            "not complete successfully."
        elsif task_progressed?(current_task, prev_progress, prev_status)
          @logger.debug("task status #{prev_status} => " +
                        "#{current_task.status}, progress #{prev_progress}%" +
                        " => #{current_task.progress}%, timer #{i} reset.")
          prev_progress = current_task.progress
          prev_status = current_task.status
          i = 0  #reset clock if status changes or running task makes progress
          sleep(delay)
        else
          @logger.debug("Approximately #{i * delay}s elapsed waiting for " +
                        "#{current_task.operation} to reach " +
                        "#{success.join("/")}/#{error_statuses.join("/")}." +
                        "  Checking again in #{delay} seconds.")
          @logger.debug("Task #{task.urn} progress: " +
            "#{current_task.progress} %.") if current_task.progress
          sleep(delay)
        end
        current_task = @connection.get(task)
        i += 1
      end
      raise ApiTimeoutError, "Task #{task.operation} did not complete " +
        "within limit of #{time_limit} seconds."
    end


    # TODO use times.upload_vapp_files
    def upload_vapp_files(vapp, ovf_directory,
        tries = @retries["upload_vapp_files"], try = 0)
      current_vapp = @connection.get(vapp)
      return current_vapp if !current_vapp.files || current_vapp.files.empty?

      @logger.debug("vapp files left to upload #{current_vapp.files}.")
      @logger.debug("vapp incomplete files left to upload " +
        "#{current_vapp.incomplete_files}.")
      raise ApiTimeoutError, "Unable to finish uploading vApp after " +
        "#{tries} tries #{current_vapp.files}." if tries == try

      current_vapp.incomplete_files.each do |f|
        # switch on extension
        case f.name.split(".").pop.downcase
          when "ovf"
            @logger.info("Uploading OVF file: " +
              "#{ovf_directory.ovf_file_path} for #{vapp.name}")
            @connection.put(f.upload_link, ovf_directory.ovf_file.read,
              Xml::MEDIA_TYPE[:OVF])
          when "vmdk"
            @logger.info("Uploading VMDK file " +
              "#{ovf_directory.vmdk_file_path(f.name)} for #{vapp.name}")
            @connection.put_file(f.upload_link,
              ovf_directory.vmdk_file(f.name))
        end
      end
      #repeat
      sleep (2 ** try)
      upload_vapp_files(current_vapp, ovf_directory, tries, try + 1)
    end

    def add_catalog_item(item, catalog_name)
      unless @admin_org.catalog(catalog_name)
        raise ArgumentError,
          "Error adding #{item.name}, catalog #{catalog_name} not found."
      end
      catalog = @connection.get(@admin_org.catalog(catalog_name))
      raise ObjectNotFoundError, "Error adding #{item.name}, catalog " +
          "#{catalog_name} not available." unless catalog
      catalog_item = Xml::WrapperFactory.create_instance("CatalogItem")
      catalog_item.name = item.name
      catalog_item.entity = item
      @logger.info("Adding #{catalog_item.name} to catalog #{catalog_name}")
      @connection.post(catalog.add_item_link, catalog_item,
        Xml::ADMIN_MEDIA_TYPE[:CATALOG_ITEM])
    end

    def generate_metadata_href(entity, key)
      raise ObjectNotFoundError, "Entity #{entity.name} does not expose a " +
        "metadata link method." if !entity.respond_to?(:metadata_link)
      "#{entity.metadata_link.href}/#{key}"
    end

    def get_vapp_by_name(name)
      @logger.debug("Getting vApp #{name}")
      vdc = get_ovdc
      node = vdc.get_vapp(name)
      raise ObjectNotFoundError, "vApp #{name} does not exist." unless node
      vapp = @connection.get(node)
      raise ObjectNotFoundError, "vApp #{name} does not exist." unless vapp
      vapp
    end

    def locality_spec(src_vapp_template, disk_locality)
      disk_locality ||= []
      locality = {}
      disk_locality.each do |disk|
        current_disk = @connection.get(disk)
        unless current_disk
          @logger.warn("Disk #{disk.name} no longer exists.")
          next
        end
        src_vapp_template.vms.each do |vm|
          locality[vm] = current_disk
        end
      end
      locality
    end

    def is_vapp_status(current_vapp, status)
      current_vapp["status"] == Xml::RESOURCE_ENTITY_STATUS[status].to_s
    end

    def rollback_upload_vapp(vapp_template)
      @logger.error("Rolling back changes.")
      begin
        delete_vapp_template(vapp_template) if vapp_template
      rescue => rollbackex
        log_exception(rollbackex, "Error in rolling back failed vApp " +
                                  "template #{vapp_name}.")
      end
    end

    def eject_media_task(vm, params, media)
      Util.retry_operation(vm.eject_media_link, @retries["default"],
          @control["backoff"]) do
        task = @connection.post(vm.eject_media_link, params,
          Xml::MEDIA_TYPE[:MEDIA_INSERT_EJECT_PARAMS])
        monitor_task(task) do |t|
          if t.status != "success"
            raise CloudError, "Error ejecting media #{media.name} from " +
              "VM #{vm.name}."
          end
          @logger.info("Ejected media #{media.name} from VM #{vm.name}.")
          return t
        end
      end
    end

    def construct_rest_logger
      @logger.debug("constructing rest_logger")
      rest_log_filename = File.join(File.dirname(@logger.instance_eval {
        @logdev }.dev.path), "rest")
      log_file = File.open(rest_log_filename, "w")
      log_file.sync = true

      @rest_logger = Logger.new(log_file || STDOUT)
      @rest_logger.level = @logger.level
      @rest_logger.formatter = @logger.formatter
    end
  end

end
