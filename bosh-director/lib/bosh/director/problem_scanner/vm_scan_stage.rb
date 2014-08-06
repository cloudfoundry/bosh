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
        vm_list = []
        vms.each do |job, index|
          instance = @instance_manager.find_by_name(@deployment.name, job, index)
          vm_list << instance.vm
        end
        vms = vm_list
      else
        vms = Models::Vm.eager(:instance).filter(deployment: @deployment).all
      end

      @event_logger.begin_stage("Scanning #{vms.size} VMs", 2)
      results = Hash.new(0)
      lock = Mutex.new

      @event_logger.track_and_log('Checking VM states') do
        ThreadPool.new(max_threads: Config.max_threads).wrap do |pool|
          vms.each do |vm|
            pool.process do
              scan_result = scan_vm(vm)
              lock.synchronize { results[scan_result] += 1 }
            end
          end
        end
      end

      @event_logger.track_and_log("#{results[:ok]} OK, " +
        "#{results[:unresponsive]} unresponsive, " +
        "#{results[:missing]} missing, " +
        "#{results[:unbound]} unbound, " +
        "#{results[:out_of_sync]} out of sync")
    end

    private

    def scan_vm(vm)
      agent_options = {
        timeout: AGENT_TIMEOUT_IN_SECONDS,
        retry_methods: {get_state: 0}
      }

      instance, mounted_disk_cid = @problem_register.get_vm_instance_and_disk(vm)

      agent = AgentClient.with_defaults(vm.agent_id, agent_options)
      begin
        state = agent.get_state

        # gather mounted disk info. (used by scan_disk)
        begin
          disk_list = agent.list_disk
          mounted_disk_cid = disk_list.first
        rescue Bosh::Director::RpcTimeout
          mounted_disk_cid = nil
        rescue RuntimeError
          # For old agents that doesn't implement list_disk we assume the disk is mounted
          @logger.info("agent.list_disk failed on agent #{vm.agent_id}")
        end
        add_disk_owner(mounted_disk_cid, vm.cid) if mounted_disk_cid

        return :out_of_sync if is_out_of_sync_vm?(vm, instance, state)
        return :unbound if is_unbound_instance_vm?(vm, instance, state)
        :ok
      rescue Bosh::Director::RpcTimeout
        # We add the disk to avoid a duplicate problem when timeouts fetching agent status (unresponsive_agent and
        # mount_info_mismatch)
        add_disk_owner(mounted_disk_cid, vm.cid) if mounted_disk_cid

        begin
          unless @cloud.has_vm?(vm.cid)
            @logger.info("Missing VM #{vm.cid}")
            @problem_register.problem_found(:missing_vm, vm)
            return :missing
          end
        rescue Bosh::Clouds::NotImplemented
        end

        @logger.info("Found unresponsive agent #{vm.agent_id}")
        @problem_register.problem_found(:unresponsive_agent, vm)
        :unresponsive
      end
    end

    def add_disk_owner(disk_cid, vm_cid)
      @agent_disks[disk_cid] ||= []
      @agent_disks[disk_cid] << vm_cid
    end

    def is_out_of_sync_vm?(vm, instance, state)
      job = state['job'] ? state['job']['name'] : nil
      index = state['index']
      if state['deployment'] != @deployment.name ||
        (instance && (instance.job != job || instance.index != index))
        @problem_register.problem_found(:out_of_sync_vm, vm,
          deployment: state['deployment'],
          job: job, index: index)
        true
      else
        false
      end
    end

    def is_unbound_instance_vm?(vm, instance, state)
      job = state['job'] ? state['job']['name'] : nil
      index = state['index']
      if job && !instance
        @logger.info("Found unbound VM #{vm.agent_id}")

        @problem_register.problem_found(:unbound_instance_vm, vm,
          job: job, index: index)
        true
      else
        false
      end
    end
  end
end
