module Bosh::Director
  class ProblemScanner::VmScanStage

    AGENT_TIMEOUT_IN_SECONDS = 10

    attr_reader :agent_disks

    def initialize(instance_manager, problem_register, cloud, deployment, event_logger, logger)
      @instance_manager = instance_manager
      @problem_register = problem_register
      @cloud = cloud
      @deployment = deployment
      @event_logger = event_logger
      @logger = logger
      @agent_disks = {}
    end

    def scan(vms=nil)
      if vms
        instances = vms.map do |job, index|
          @instance_manager.find_by_name(@deployment, job, index)
        end
      else
        instances = Models::Instance.filter(deployment: @deployment).exclude(vm_cid: nil).all
      end

      @event_logger.begin_stage("Scanning #{instances.size} VMs", 2)
      results = Hash.new(0)
      lock = Mutex.new

      @event_logger.track_and_log('Checking VM states') do
        ThreadPool.new(max_threads: Config.max_threads).wrap do |pool|
          instances.each do |instance|
            pool.process do
              scan_result = scan_vm(instance)
              lock.synchronize { results[scan_result] += 1 }
            end
          end
        end
      end

      @event_logger.track_and_log("#{results[:ok]} OK, " +
        "#{results[:unresponsive]} unresponsive, " +
        "#{results[:missing]} missing, " +
        "#{results[:unbound]} unbound")
    end

    private

    def scan_vm(instance)
      agent_options = {
        timeout: AGENT_TIMEOUT_IN_SECONDS,
        retry_methods: {get_state: 0}
      }

      mounted_disk_cid = @problem_register.get_disk(instance)

      agent = AgentClient.with_vm_credentials_and_agent_id(instance.credentials, instance.agent_id, agent_options)
      begin
        agent.get_state

        # gather mounted disk info. (used by scan_disk)
        begin
          disk_list = agent.list_disk
          mounted_disk_cid = disk_list.first
        rescue Bosh::Director::RpcTimeout
          mounted_disk_cid = nil
        end
        add_disk_owner(mounted_disk_cid, instance.vm_cid) if mounted_disk_cid

        :ok
      rescue Bosh::Director::RpcTimeout
        # We add the disk to avoid a duplicate problem when timeouts fetching agent status (unresponsive_agent and
        # mount_info_mismatch)
        add_disk_owner(mounted_disk_cid, instance.vm_cid) if mounted_disk_cid

        begin
          if instance.vm_cid && !@cloud.has_vm?(instance.vm_cid)
            @logger.info("Missing VM #{instance.vm_cid}")
            @problem_register.problem_found(:missing_vm, instance)
            return :missing
          end
        rescue Bosh::Clouds::NotImplemented
        end

        @logger.info("Found unresponsive agent #{instance.agent_id}")
        @problem_register.problem_found(:unresponsive_agent, instance)
        :unresponsive
      end
    end

    def add_disk_owner(disk_cid, vm_cid)
      @agent_disks[disk_cid] ||= []
      @agent_disks[disk_cid] << vm_cid
    end
  end
end
