module Bosh::Director
  module Jobs
    module CloudCheck
      class Scan < BaseJob
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
            scan_instances
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
          @logger.info("Scanning persistent disks")
          @logger.info("Looking for orphaned disks")
          Models::PersistentDisk.filter(:active => false).all.each do |disk|
            # TODO: filter further by deployment, right now this
            # tries to operate on disks from other deployments!
            @logger.info("Found orphaned disk: #{disk.id}")
            problem_found(:orphan_disk, disk)
          end
        end

        def scan_vms
          @logger.info("Scanning VMs")
          # TBD
        end

        def scan_instances
          @logger.info("Scanning instances")
          # TBD
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
