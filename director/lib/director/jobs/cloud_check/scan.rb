# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    module CloudCheck
      class Scan < BaseJob
        AGENT_TIMEOUT = 10 # seconds

        @queue = :normal

        # @param [String] deployment_name Deployment name
        def initialize(deployment_name)
          super

          @deployment_manager = Api::DeploymentManager.new
          @deployment = @deployment_manager.find_by_name(deployment_name)

          @problem_lock = Mutex.new
          @agent_disks = {}
        end

        def perform
          begin
            with_deployment_try_lock do
              reset
              # TODO: decide if scanning procedures should be
              # extracted into their own classes (for clarity)
              scan_vms
              # always run 'scan_vms' before 'scan_disks'
              scan_disks
              "scan complete"
            end
          rescue Lock::LockBusy
            raise "Unable to get deployment lock, maybe a deployment is " +
                  "in progress. Try again later."
          end
        end

        # Cleans up previous scan artifacts
        def reset
          # TODO: finalize the approach we want to use:
          # either close all open problems
          # or update open ones that match by some criteria.
          # In a latter case we don't actually want to reset anything.
        end

        def scan_disks
          disks = Models::PersistentDisk.eager(:instance).all.select do |disk|
            disk.instance && disk.instance.deployment_id == @deployment.id
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

        def scan_vms
          vms = Models::Vm.eager(:instance).
            filter(:deployment_id => @deployment.id).all

          begin_stage("Scanning #{vms.size} VMs", 2)
          results = Hash.new(0)
          lock = Mutex.new

          track_and_log("Checking VM states") do
            ThreadPool.new(:max_threads => 32).wrap do |pool|
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
            :retry_methods => { :get_state => 0 }
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
            job = state["job"] ? state["job"]["name"] : nil
            index = state["index"]

            # gather mounted disk info. (used by scan_disk)
            begin
              disk_list = agent.list_disk
              mounted_disk_cid = disk_list.first
            rescue RuntimeError => e
              logger.info("agent.list_disk failed on agent #{vm.agent_id}")
            end
            add_disk_owner(mounted_disk_cid, vm.cid) if mounted_disk_cid

            if state["deployment"] != @deployment.name ||
                (instance && (instance.job != job || instance.index != index))
              problem_found(:out_of_sync_vm, vm,
                            :deployment => state["deployment"],
                            :job => job, :index => index)
              return :out_of_sync
            end

            if job && !instance
              logger.info("Found unbound VM #{vm.agent_id}")
              problem_found(:unbound_instance_vm, vm,
                            :job => job, :index => index)
              return :unbound
            end
            :ok
          rescue Bosh::Director::Client::TimeoutException
            # unresponsive disk, not invalid disk_info
            add_disk_owner(mounted_disk_cid, vm.cid) if mounted_disk_cid

            logger.info("Found unresponsive agent #{vm.agent_id}")
            problem_found(:unresponsive_agent, vm)
            :unresponsive
          end
        end

        def problem_found(type, resource, data = {})
          @problem_lock.synchronize do
            # TODO: audit trail
            similar_open_problems = Models::DeploymentProblem.
              filter(:deployment_id => @deployment.id, :type => type.to_s,
                     :resource_id => resource.id, :state => "open").all

            if similar_open_problems.size > 1
              raise CloudcheckTooManySimilarProblems,
                    "More than one problem of type `#{type}' " +
                    "exists for resource #{type} #{resource.id}"
            end

            if similar_open_problems.empty?
              problem = Models::DeploymentProblem.
                create(:type => type.to_s, :resource_id => resource.id,
                       :state => "open", :deployment_id => @deployment.id,
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

        def add_disk_owner(disk_cid, vm_cid)
          @agent_disks[disk_cid] ||= []
          @agent_disks[disk_cid] << vm_cid
        end

        def get_disk_owners(disk_cid)
          @agent_disks[disk_cid]
        end

        def with_deployment_try_lock
          Lock.new("lock:deployment:#{@deployment.name}").try_lock do
            yield
          end
        end
      end
    end
  end
end
