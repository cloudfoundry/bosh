module EsxCloud

  class Cloud

    BOSH_AGENT_PROPERTIES_ID = "Bosh_Agent_Properties"

    attr_accessor :client

    def initialize(options)
      @logger = Bosh::Director::Config.logger
      @reqID = 0
      @server = "middle"
      @agent_properties = options["agent"]
      @vmMac = "00:50:56:00:09:"
      @vmMacID = 10
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

    def send_request(payload)
      @logger.info("ESXMGR: Inside send req #{payload}")
      rtn = false
      rtn_payload =''
      uri = "nats://esxmgr:esxmgr@10.20.142.82:11009"
      NATS.start(:uri => uri) {
        b = EsxMQ::Backend.new(@server)
        @reqID = @reqID + 1
        @logger.info("ESXMGR: Here before subscribe")
        b.subscribe { |rID, msg|
          @logger.info("ESXMGR: received msg #{msg}, payload is #{msg.payload}, status is #{msg.returnStatus}")
          raise "bad message #{msg}, rID #{rID} , reqID #{@reqID}" if rID != @reqID.to_s
          if (msg.returnStatus == EsxMQ::ESXReturnStatus::SUCCESS)
            rtn_payload = getPayloadMsg(msg.payload)
            puts "Got payload............#{rtn_payload}, #{rtn_payload.value}" if rtn_payload
            rtn = true
          end
          NATS.stop
        }
        req = EsxMQ::RequestMsg.new(@reqID)
        req.payload = payload
        @logger.info("ESXMGR: sending req #{req}")
        b.publish(req)
      }
      if rtn
        puts "successfully sent message #{payload}, got back #{rtn_payload}"
      else
        puts "request failed #{payload}"
      end
      return rtn, rtn_payload
    end

    def create_stemcell(image, _)
      with_thread_name("create_stemcell(#{image}, _)") do
        result = nil
        Dir.mktmpdir do |temp_dir|
          @logger.info("Extracting stemcell to: #{temp_dir}")
          output = `tar -C #{temp_dir} -xzf #{image} 2>&1`
          raise "Corrupt image, tar exit status: #{$?.exitstatus} output: #{output}" if $?.exitstatus != 0

          ovf_file = Dir.entries(temp_dir).find {|entry| File.extname(entry) == ".ovf"}
          raise "Missing OVF" if ovf_file.nil?
          ovf_file = File.join(temp_dir, ovf_file)

          name = "sc-#{generate_unique_name}"
          @logger.info("Generated name: #{name}")


          # upload stemcell to esx controller

          # send "create stemcell" command to controller
          createSC = EsxMQ::CreateStemcellMsg.new('sc-1234-abc-xxx', '/var/esxcloud/stemcells/ubuntu.ovf')
          if (send_request(createSC))
            # on success set result to name
            result = name
          end
        end
        result
      end
    end

    def delete_stemcell(stemcell)
      with_thread_name("delete_stemcell(#{stemcell})") do
        # send delete stemcell command to esx controller
        deleteSC = EsxMQ::DeleteStemcellMsg.new(stemcell)
        send_request(deleteSC)
      end
    end

    def generate_network_env(devices, networks, dvs_index)
      nics = {}

      devices.each do |device|
        if device.kind_of?(VirtualEthernetCard)
          backing = device.backing
          if backing.kind_of?(VirtualEthernetCardDistributedVirtualPortBackingInfo)
            v_network_name = dvs_index[device.backing.port.portgroupKey]
          else
            v_network_name = device.backing.deviceName
          end
          allocated_networks = nics[v_network_name] || []
          allocated_networks << device
          nics[v_network_name] = allocated_networks
        end
      end

      network_env = {}
      networks.each do |network_name, network|
        network_entry             = network.dup
        v_network_name            = network["cloud_properties"]["name"]
        nic                       = nics[v_network_name].pop
        network_entry["mac"]      = nic.macAddress
        network_env[network_name] = network_entry
      end
      network_env
    end

    def create_vm(agent_id, stemcell, resource_pool, networks, disk_locality = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
        result = nil
        memory = resource_pool["ram"]
        disk = resource_pool["disk"]
        cpu = resource_pool["cpu"]

        # TODO find least loaded host (could be done transparently by the ESX controller)

        # TODO do we need to worry about disk locality

        name = "vm-#{generate_unique_name}"
        @logger.info("Creating vm: #{name}")

        createVM = EsxMQ::CreateVmMsg.new(name)
        createVM.cpu = resource_pool["cpu"]
        createVM.ram = resource_pool["ram"]
        networks.each_value do |network|
          net = Hash.new
          net["vswitch"] = network["cloud_properties"]["name"]
          net["mac"] =  @vmMac + @vmMacID.to_s
          @vmMacID = @vmMacID + 1
        end
        createVM.stemcell = stemcell
        # TODO fix these
        system_disk = 0
        ephemeral_disk = 1

        network_env = build_agent_network_env(devices, networks)
        # TODO fix disk_env
        disk_env = { "system" => system_disk,
                     "ephemeral" => ephemeral_disk,
                     "persistent" => {}
                   }
        createVM.guestInfo = generate_agent_env(name, name, agent_id, network_env, disk_env)

        if send_request(createVM)
          result = name
        end
        result
      end
    end

    def delete_vm(vm_cid)
      with_thread_name("delete_vm(#{vm_cid})") do
        @logger.info("Deleting vm: #{vm_cid}")

        deleteVM = EsxMQ::DeleteVmMsg.new(vm_cid)
        send_request(deleteVM)
      end
    end

    def configure_networks(vm_cid, networks)
      with_thread_name("configure_networks(#{vm_cid}, ...)") do
        @logger.info("Configuring: #{vm_cid} to use the following network settings: #{networks.pretty_inspect}")
        raise "ESXCLOUD: configure networks is not implemented yet"
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
