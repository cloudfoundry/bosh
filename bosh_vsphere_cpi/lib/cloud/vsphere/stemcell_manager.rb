require "cloud/vsphere/vm_configurable"

module VSphereCloud
  class StemcellManager
    include VmConfigurable

    def initialize(client, logger, resources)
      @client = client
      @logger = logger
      @resources = resources
    end

    def create(image, name, dir)
      @logger.info("Extracting stemcell to: #{dir}")
      output = `tar -C #{dir} -xzf #{image} 2>&1`
      raise "Corrupt image, tar exit status: #{$?.exitstatus} output: #{output}" if $?.exitstatus != 0

      ovf_file = Dir.entries(dir).find { |entry| File.extname(entry) == ".ovf" }
      raise "Missing OVF" if ovf_file.nil?
      ovf_file = File.join(dir, ovf_file)

      stemcell_size = File.size(image) / (1024 * 1024)
      cluster, datastore = @resources.place(0, stemcell_size, [])
      @logger.info("Deploying to: #{cluster.mob} / #{datastore.mob}")

      import_spec_result = import_ovf(name, ovf_file, cluster.resource_pool.mob, datastore.mob)
      lease = obtain_nfc_lease(cluster.resource_pool.mob, import_spec_result.import_spec,
                               cluster.datacenter.template_folder.mob)
      @logger.info("Waiting for NFC lease")
      state = wait_for_nfc_lease(lease)
      raise "Could not acquire HTTP NFC lease (state is: #{state})" unless state == Vim::HttpNfcLease::State::READY

      @logger.info("Uploading")
      upload_ovf(ovf_file, lease, import_spec_result.file_item).tap do |vm|
        @logger.info("Removing NICs")
        devices = client.get_property(vm, Vim::VirtualMachine, "config.hardware.device", ensure_all: true)
        nics = devices.select { |device| device.kind_of?(Vim::Vm::Device::VirtualEthernetCard) }
        device_changes = nics.map { |nic| create_delete_device_spec(nic) }

        config = Vim::Vm::ConfigSpec.new
        config.device_change = device_changes
        @client.reconfig_vm(vm, config)
      end
    end

    def delete(stemcell)
      Bosh::ThreadPool.new(max_threads: 32, logger: @logger).wrap do |pool|
        @resources.datacenters.each_value do |datacenter|
          @logger.info("Looking for stemcell replicas in: #{datacenter.name}")
          templates = @client.get_property(datacenter.template_folder.mob, Vim::Folder, "childEntity", ensure_all: true)
          template_properties = @client.get_properties(templates, Vim::VirtualMachine, ["name"])
          template_properties.each_value do |properties|
            template_name = properties["name"].gsub("%2f", "/")
            if template_name.split("/").first.strip == stemcell
              @logger.info("Found: #{template_name}")
              pool.process do
                @logger.info("Deleting: #{template_name}")
                @client.delete_vm(properties[:obj])
                @logger.info("Deleted: #{template_name}")
              end
            end
          end
        end
      end
    end

    private

    def import_ovf(name, ovf, resource_pool, datastore)
      import_spec_params = Vim::OvfManager::CreateImportSpecParams.new
      import_spec_params.entity_name = name
      import_spec_params.locale = 'US'
      import_spec_params.deployment_option = ''

      ovf_file = File.open(ovf)
      ovf_descriptor = ovf_file.read
      ovf_file.close

      @client.service_content.ovf_manager.create_import_spec(ovf_descriptor, resource_pool,
                                                             datastore, import_spec_params)
    end

    def obtain_nfc_lease(resource_pool, import_spec, folder)
      resource_pool.import_vapp(import_spec, folder, nil)
    end

    def wait_for_nfc_lease(lease)
      loop do
        state = @client.get_property(lease, Vim::HttpNfcLease, "state")
        unless state == Vim::HttpNfcLease::State::INITIALIZING
          return state
        end
        sleep(1.0)
      end
    end

    def upload_ovf(ovf, lease, file_items)
      info = @client.get_property(lease, Vim::HttpNfcLease, "info", ensure_all: true)
      lease_updater = LeaseUpdater.new(client, lease)

      info.device_url.each do |device_url|
        device_key = device_url.import_key
        file_items.each do |file_item|
          if device_key == file_item.device_id
            http_client = HTTPClient.new
            http_client.send_timeout = 14400 # 4 hours
            http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

            disk_file_path = File.join(File.dirname(ovf), file_item.path)
            disk_file = File.open(disk_file_path)
            disk_file_size = File.size(disk_file_path)

            progress_thread = Thread.new do
              loop do
                lease_updater.progress = disk_file.pos * 100 / disk_file_size
                sleep(2)
              end
            end

            @logger.info("Uploading disk to: #{device_url.url}")

            http_client.post(device_url.url, disk_file, {"Content-Type" => "application/x-vnd.vmware-streamVmdk",
                              "Content-Length" => disk_file_size})

            progress_thread.kill
            disk_file.close
          end
        end
      end
      lease_updater.finish
      info.entity
    end
  end
end
