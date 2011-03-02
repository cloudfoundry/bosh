module EsxCloud

  class Cloud
    @req_id = 0
    @lock = Mutex.new

    class << self
      attr_accessor :req_id, :lock 
    end

    BOSH_AGENT_PROPERTIES_ID = "Bosh_Agent_Properties"

    DEFAULT_OPERATION_RETRIES = 3

    attr_accessor :client

    def initialize(options)
      @logger = Bosh::Director::Config.logger
      @agent_properties = options["agent"]
      @esxmgr = options["esxmgr"]

      # Set default
      @esxmgr["operation_retry"] ||= DEFAULT_OPERATION_RETRIES
      @esxmgr["operation_retry"] = 1 if @esxmgr["operation_retry"] == 0

      # blobstore
      blobstore = @esxmgr['blobstore']
      @blobstore_endpoint = blobstore['endpoint']
      @headers = {}
      if blobstore["user"] && blobstore["password"]
        @headers["Authorization"] = "Basic " + Base64.encode64("#{blobstore["user"]}:#{blobstore["password"]}")
      end
      @client = HTTPClient.new

      # Start EM (if required)
      self.class.lock.synchronize do
        unless EM.reactor_running? 
          Thread.new {
            EM.run{}
          }
          while !EM.reactor_running?
            @logger.info("ESXCLOUD: waiting for EM to start")
            sleep(0.1)
          end
        end
        raise "EM could not be started" unless EM.reactor_running?
      end

      opts = {}
      opts["nats"] = options["nats"]
      opts["logger"] = @logger

      @logger.info("ESXCLOUD: nats <#{options["nats"]}> esxmgr <#{@esxmgr}>")

      # Call after EM is running
      EsxMQ::Config.configure(opts)
      EsxMQ::TimedRequest.init(@esxmgr["inbox"])
    end

    def generate_unique_name
      UUIDTools::UUID.random_create.to_s
    end

    def generate_agent_env(name, vm, agent_id, networking_env, disk_env)
      vm_env = {
          "name" => name,
          "id" => vm
      }
      env = {}
      env["vm"] = vm_env
      env["agent_id"] = agent_id
      env["networks"] = networking_env
      env["disks"] = disk_env
      env.merge!(@agent_properties)
      env
    end

    def build_agent_network_env(devices, networks)
      network_env = {}
      networks.each do |network_name, network|
        network_entry = network.dup
        devices.each do |d|
          if d["vswitch"] == network["cloud_properties"]["name"]
            network_entry["mac"] = d["mac"]
            break
          end
        end
        network_env[network_name] = network_entry
      end
      network_env
    end

    def build_agent_network_env_new(networks)
      network_env = {}
      networks.each do |network_name, network|
        network_env[network_name] = network.dup
      end
      network_env
    end

    def send_request(payload, timeout=nil)
      req_id = 0
      self.class.lock.synchronize do
        req_id = self.class.req_id
        self.class.req_id = self.class.req_id + 1
      end

      req = EsxMQ::RequestMsg.new(req_id)
      req.payload = payload

      @logger.info("ESXCLOUD: sending request #{payload}")
      rtn = EsxMQ::TimedRequest.send(payload, timeout)

      @logger.info("ESXCloud, request #{payload} #{rtn["rtn"]} #{rtn["rtn_payload"]}")
      return rtn["rtn"], rtn["rtn_payload"]
    end

    def send_request_with_retry(payload, timeout=nil)
      raise "Bad config for operation retry" if @esxmgr["operation_retry"] <= 0

      rtn = rtn_payload = nil
      @esxmgr["operation_retry"].times do
        rtn, rtn_payload = send_request(payload, timeout)
        break if rtn
      end
      return rtn, rtn_payload
    end

    def create_stemcell(image, _)
      with_thread_name("create_stemcell(#{image}, _)") do
        result = nil

        name = "sc-#{generate_unique_name}"
        file = open(image, "rb")

        # upload stemcell to blobstore
        response = @client.post("#{@blobstore_endpoint}/resources", {:name => name, :content => file}, @headers)
        if response.status != 200
          raise "Could not create upload to blobstore, #{response.status}/#{response.content}"
        end
        file.close

        # send "create stemcell" command to controller
        create_sc = EsxMQ::CreateStemcellMsg.new(name, name)

        rtn, rtn_payload = send_request_with_retry(create_sc, 3600)

        if rtn
          @logger.info("ESXCLOUD: create_stemcell #{name} succeeded <#{result}>")
          result = name
        else
          @logger.warn("ESXCLOUD: failed to create_stemcell #{name} #{rtn_payload.inspect if rtn_payload}")
          # Try to cleanup
          delete_stemcell(name)
        end
        result
      end
    end

    def delete_stemcell(stemcell)
      with_thread_name("delete_stemcell(#{stemcell})") do
        # send delete stemcell command to esx controller
        delete_sc = EsxMQ::DeleteStemcellMsg.new(stemcell)
        rtn, rtn_status = send_request_with_retry(delete_sc)
        if rtn
          @logger.info("Delete stemcell #{stemcell} succeeded")
        else
          @logger.warn("Failed to delete stemcell #{stemcell} #{rtn_status.inspect if rtn_status}")
        end
      end
    end

    def create_vm(agent_id, stemcell, resource_pool, networks, disk_locality = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
        result = nil

        # SCSI disk unit numbers
        system_disk = 0 # Always reserved for system disk
        ephemeral_disk = 1

        # TODO do we need to worry about disk locality
        name = "vm-#{generate_unique_name}"
        @logger.info("ESXCLOUD: Creating vm: #{name}")

        create_vm = EsxMQ::CreateVmMsg.new(name)
        create_vm.cpu = resource_pool["cpu"]
        create_vm.ram = resource_pool["ram"]
        create_vm.disk = resource_pool["disk"]

        devices = []
        networks.each_value do |network|
          net = Hash.new
          net["vswitch"] = network["cloud_properties"]["name"]
          net["mac"] =  "00:00:00:00:00:00"
          devices << net
        end

        create_vm.stemcell = stemcell

        network_env = build_agent_network_env(devices, networks)
        # TODO fix disk_env
        disk_env = {"system" => system_disk,
                    "ephemeral" => ephemeral_disk,
                    "persistent" => {}}
        create_vm.guestInfo = generate_agent_env(name, name, agent_id, network_env, disk_env)

        rtn, rtn_status = send_request_with_retry(create_vm)
        if rtn
          @logger.info("Create vm for agent #{agent_id} #{name} succeeded")
          result = name
        else
          @logger.info("Create vm for agent #{agent_id} #{name} failed, #{rtn_status.inspect if rtn_status}")
          # Try to cleanup
          delete_vm(name)
        end
        result
      end
    end

    def delete_vm(vm_cid)
      with_thread_name("delete_vm(#{vm_cid})") do
        @logger.info("ESXCLOUD: Deleting vm: #{vm_cid}")

        delete_vm = EsxMQ::DeleteVmMsg.new(vm_cid)
        rtn, rtn_status = send_request_with_retry(delete_vm)

        if rtn
          @logger.info("Delete vm #{vm_cid} succeeded")
        else
          @logger.warn("Delete vm #{vm_cid} failed, #{rtn_status.inspect if rtn_status}")
        end
      end
    end

    def configure_networks(vm_cid, networks)
      with_thread_name("configure_networks(#{vm_cid}, ...)") do
        @logger.info("Configuring: #{vm_cid} to use the following network settings: #{networks.pretty_inspect}")
        network_env = build_agent_network_env_new(networks)
        configure_network = EsxMQ::ConfigureNetworkMsg.new(vm_cid, network_env)

        rtn, rtn_status = send_request_with_retry(configure_network)
        if rtn
          @logger.info("Configure network of vm #{vm_cid} succeeded")
        else
          @logger.info("Configure network of vm #{vm_cid} failed #{rtn_status.inspect if rtn_status}")
        end
      end
    end

    def attach_disk(vm_cid, disk_cid)
      with_thread_name("attach_disk(#{vm_cid}, #{disk_cid})") do
        @logger.info("Attaching disk: #{disk_cid} on vm: #{vm_cid}")
        raise "ESXCLOUD: attach disk is not implemented yet"
      end
    end

    def detach_disk(vm_cid, disk_cid)
      with_thread_name("detach_disk(#{vm_cid}, #{disk_cid})") do
        @logger.info("Detaching disk: #{disk_cid} from vm: #{vm_cid}")
        raise "ESXCLOUD: Detaching disk is not implemented yet"
      end
    end

    def create_disk(size, _ = nil)
      with_thread_name("create_disk(#{size}, _)") do
        @logger.info("Creating disk with size: #{size}")
        raise "ESXCLOUD: Create disk not implemented yet"
      end
    end

    def delete_disk(disk_cid)
      with_thread_name("delete_disk(#{disk_cid})") do
        @logger.info("Deleting disk: #{disk_cid}")
        raise "ESXCLOUD: Delete disk not implemented yet"
      end
    end

    def validate_deployment(old_manifest, new_manifest)
      # TODO: still needed? what does it verify? cloud properties? should be replaced by normalize cloud properties?
      @logger.info("Validate deployment")
      raise "ESXCLOUD: Validate deployment not implemented yet"
    end
  end
end
