# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class ProblemScanner

    AGENT_TIMEOUT = 10 # seconds

    attr_reader :event_log, :logger

    @queue = :normal

    # @param [String] deployment_name Deployment name
    def initialize(deployment_name)
      @deployment_manager = Api::DeploymentManager.new
      @deployment = @deployment_manager.find_by_name(deployment_name)
      @instance_manager = Api::InstanceManager.new

      @problem_lock = Mutex.new
      @agent_disks = {}

      #temp
      @event_log = Config.event_log
      @logger = Config.logger
    end


    #TODO : remove/refactor shared with base_job
    def begin_stage(stage_name, n_steps)
      event_log.begin_stage(stage_name, n_steps)
      logger.info(stage_name)
    end
    #TODO : remove/refactor shared with base_job
    def track_and_log(task, log = true)
      event_log.track(task) do |ticker|
        logger.info(task) if log
        yield ticker if block_given?
      end
    end

    def reset(vms=nil)
      if vms
        vms.each do |job, indices|
          indices.each do |index|
            instance = @instance_manager.find_by_name(@deployment.name, job, index)
            Models::DeploymentProblem.where(deployment: deployment,
                                            :resource_id => instance.vm.id,
                                            :state => "open").update(state: "closed")
          end
        end
      else
        Models::DeploymentProblem.where(state: "open", deployment: deployment).update(state: "closed")
      end
    end

    def scan_disks
      disks = Models::PersistentDisk.eager(:instance).all.select do |disk|
        disk.instance && disk.instance.deployment_id == deployment.id
      end
      results = Hash.new(0)

      begin_stage("Scanning #{disks.size} persistent disks", 2)

      track_and_log("Looking for inactive disks") do
        disks.each do |disk|
          scan_result = scan_disk(disk)
          results[scan_result] += 1
        end
      end

      track_and_log("#{results[:ok]} OK, " +
                        "#{results[:inactive]} inactive, " +
                        "#{results[:mount_info_mismatch]} mount-info mismatch")
    end

    def scan_vms(vms=nil)
      if vms
        vm_list = []
        vms.each do |job, indices|
          indices.each do |index|
            instance = @instance_manager.find_by_name(@deployment.name, job, index)
            vm_list << instance.vm
          end
        end
        vms = vm_list
      else
        vms = Models::Vm.eager(:instance).filter(deployment: deployment).all
      end

      begin_stage("Scanning #{vms.size} VMs", 2)
      results = Hash.new(0)
      lock = Mutex.new

      track_and_log("Checking VM states") do
        ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
          vms.each do |vm|
            pool.process do
              scan_result = scan_vm(vm)
              lock.synchronize { results[scan_result] += 1 }
            end
          end
        end
      end

      track_and_log("#{results[:ok]} OK, " +
                        "#{results[:unresponsive]} unresponsive, " +
                        "#{results[:missing]} missing, " +
                        "#{results[:unbound]} unbound, " +
                        "#{results[:out_of_sync]} out of sync")
    end

    def scan_disk(disk)
      # inactive disks
      unless disk.active
        logger.info("Found inactive disk: #{disk.id}")
        problem_found(:inactive_disk, disk)
        return :inactive
      end

      disk_cid = disk.disk_cid
      vm_cid = nil

      if disk.instance && disk.instance.vm
        vm_cid = disk.instance.vm.cid
      end

      if vm_cid.nil?
        # With the db dependencies this should not happen.
        logger.warn("Disk #{disk_cid} is not associated to any VM. " +
                        "Skipping scan")
        return :ok
      end

      owner_vms = get_disk_owners(disk_cid) || []
      # active disk is not mounted or mounted more than once -or-
      # the disk is mounted on a vm that is different form the record.
      if owner_vms.size != 1 || owner_vms.first != vm_cid
        logger.info("Found problem in mount info: " +
                        "active disk #{disk_cid} mounted on " +
                        "#{owner_vms.join(', ')}")
        problem_found(:mount_info_mismatch, disk, :owner_vms => owner_vms)
        return :mount_info_mismatch
      end
      :ok
    end

    def scan_vm(vm)
      agent_options = {
          :timeout => AGENT_TIMEOUT,
          :retry_methods => {:get_state => 0}
      }

      instance = nil
      mounted_disk_cid = nil
      @problem_lock.synchronize do
        instance = vm.instance
        mounted_disk_cid = instance.persistent_disk_cid if instance
      end

      agent = AgentClient.new(vm.agent_id, agent_options)
      begin
        state = agent.get_state # TODO: handle invalid state

        # gather mounted disk info. (used by scan_disk)
        begin
          disk_list = agent.list_disk
          mounted_disk_cid = disk_list.first
        rescue RuntimeError => e
          logger.info("agent.list_disk failed on agent #{vm.agent_id}")
        end
        add_disk_owner(mounted_disk_cid, vm.cid) if mounted_disk_cid

        return :out_of_sync if is_out_of_sync_vm?(vm, instance, state)
        return :unbound if is_unbound_instance_vm?(vm, instance, state)
        :ok
      rescue Bosh::Director::RpcTimeout
        # unresponsive disk, not invalid disk_info
        add_disk_owner(mounted_disk_cid, vm.cid) if mounted_disk_cid

        begin
          unless cloud.has_vm?(vm.cid)
            logger.info("Missing VM #{vm.cid}")
            problem_found(:missing_vm, vm)
            return :missing
          end
        rescue Bosh::Clouds::NotImplemented
        end

        logger.info("Found unresponsive agent #{vm.agent_id}")
        problem_found(:unresponsive_agent, vm)
        :unresponsive
      end
    end

    def problem_found(type, resource, data = {})
      @problem_lock.synchronize do
        # TODO: audit trail
        similar_open_problems = Models::DeploymentProblem.
            filter(:deployment_id => deployment.id, :type => type.to_s,
                   :resource_id => resource.id, :state => "open").all

        if similar_open_problems.size > 1
          raise CloudcheckTooManySimilarProblems,
                "More than one problem of type `#{type}' " +
                    "exists for resource #{type} #{resource.id}"
        end

        if similar_open_problems.empty?
          problem = Models::DeploymentProblem.
              create(:type => type.to_s, :resource_id => resource.id,
                     :state => "open", :deployment_id => deployment.id,
                     :data => data, :counter => 1)

          logger.info("Created problem #{problem.id} (#{problem.type})")
        else
          # This assumes we are running with deployment lock acquired,
          # so there is no possible update conflict
          problem = similar_open_problems[0]
          problem.data = data
          problem.last_seen_at = Time.now
          problem.counter += 1
          problem.save
          logger.info("Updated problem #{problem.id} (#{problem.type}), " +
                          "count is now #{problem.counter}")
        end
      end
    end


    private
    attr_reader :deployment

    def is_out_of_sync_vm?(vm, instance, state)
      job = state["job"] ? state["job"]["name"] : nil
      index = state["index"]
      if state["deployment"] != deployment.name ||
          (instance && (instance.job != job || instance.index != index))
        problem_found(:out_of_sync_vm, vm,
                      :deployment => state["deployment"],
                      :job => job, :index => index)
        true
      else
        false
      end
    end

    def is_unbound_instance_vm?(vm, instance, state)
      job = state["job"] ? state["job"]["name"] : nil
      index = state["index"]
      if job && !instance
        logger.info("Found unbound VM #{vm.agent_id}")
        problem_found(:unbound_instance_vm, vm,
                      :job => job, :index => index)
        true
      else
        false
      end
    end

    def add_disk_owner(disk_cid, vm_cid)
      @agent_disks[disk_cid] ||= []
      @agent_disks[disk_cid] << vm_cid
    end

    def get_disk_owners(disk_cid)
      @agent_disks[disk_cid]
    end

    def cloud
      Config.cloud
    end
  end
end
