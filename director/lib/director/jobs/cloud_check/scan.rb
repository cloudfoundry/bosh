module Bosh::Director
  module Jobs
    module CloudCheck
      class Scan < BaseJob
        AGENT_TIMEOUT = 10 # seconds
        @queue = :normal

        # TODO: add event and regular logging
        def initialize(deployment_name)
          super
          @deployment = Models::Deployment.find(:name => deployment_name)
          raise "Deployment `#{deployment_name}' not found" if @deployment.nil?
        end

        def perform
          with_deployment_lock do
            started_at = Time.now
            reset
            # TODO: decide if scanning procedures should be
            # extracted into their own classes (for clarity)
            scan_disks
            scan_vms
            "scan complete"
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

          track_and_log("#{results[:ok]} OK, #{results[:inactive]} inactive")
        end

        def scan_vms
          vms = Models::Vm.eager(:instance).filter(:deployment_id => @deployment.id).all
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
                        "#{results[:unbound]} unbound")
        end

        def scan_disk(disk)
          if !disk.active
            @logger.info("Found inactive disk: #{disk.id}")
            problem_found(:inactive_disk, disk)
            :inactive
          end
          :ok
        end

        def scan_vm(vm)
          agent_options = {
            :timeout => AGENT_TIMEOUT,
            :retry_methods => { :get_state => 0 }
          }

          agent = AgentClient.new(vm.agent_id, agent_options)
          begin
            state = agent.get_state
            # TODO: handle invalid state
            if vm.instance.nil? && !state["job"].nil?
              job = state["job"].kind_of?(Hash) ? state["job"]["name"] : nil
              index = state["index"]
              problem_found(:unbound_instance_vm, vm, :job => job, :index => index)
              :unbound
            else
              :ok
            end
          rescue Bosh::Director::Client::TimeoutException
            @logger.info("Found unresponsive agent #{vm.agent_id}")
            problem_found(:unresponsive_agent, vm)
            :unresponsive
          end
        end

        def problem_found(type, resource, data = {})
          # TODO: audit trail
          similar_open_problems = Models::DeploymentProblem.
            filter(:deployment_id => @deployment.id, :type => type.to_s,
                   :resource_id => resource.id, :state => "open").all

          if similar_open_problems.size > 1
            raise "More than one problem of type `#{type}' exists for resource #{resource.id}"
          end

          if similar_open_problems.empty?
            problem = Models::DeploymentProblem.
              create(:type => type.to_s, :resource_id => resource.id, :state => "open",
                     :deployment_id => @deployment.id, :data => data, :counter => 1)

            @logger.info("Created problem #{problem.id} (#{problem.type})")
          else
            # This assumes we are running with deployment lock acquired,
            # so there is no possible update conflict
            problem = similar_open_problems[0]
            problem.data = data
            problem.last_seen_at = Time.now
            problem.counter += 1
            problem.save
            @logger.info("Updated problem #{problem.id} (#{problem.type}), count is now #{problem.counter}")
          end
        end

        private

        def with_deployment_lock
          Lock.new("lock:deployment:#{@deployment.name}").lock do
            yield
          end
        end
      end
    end
  end
end
