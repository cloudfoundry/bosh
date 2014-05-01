# This job is used by the resurrector health monitor plugin, to notify the director that
# it needs to scan the job(s) for problems (only unresponsive agents) and then try to
# automatically try to fix it by recreating the job.
module Bosh::Director
  module Jobs
    module CloudCheck
      class ScanAndFix < BaseJob
        include LockHelper

        attr_reader :filtered_jobs

        @queue = :normal

        def self.job_type
          :cck_scan_and_fix
        end

        def initialize(deployment_name, jobs, fix_stateful_jobs=false)
          @deployment_manager = Api::DeploymentManager.new
          @instance_manager = Bosh::Director::Api::InstanceManager.new
          @deployment = @deployment_manager.find_by_name(deployment_name)
          @jobs = jobs # [[j1, i1], [j1, i2], [j2, i1], [j2, i2], ...]
          @fix_stateful_jobs = fix_stateful_jobs
        end

        def perform
          jobs = filtered_jobs

          begin
            with_deployment_lock(@deployment, :timeout => 0) do

              scanner = ProblemScanner.new(@deployment)
              scanner.reset(jobs)
              scanner.scan_vms(jobs)

              resolver = ProblemResolver.new(@deployment)
              resolver.apply_resolutions(resolutions(jobs))

              "scan and fix complete"
            end
          rescue Lock::TimeoutError
            raise "Unable to get deployment lock, maybe a deployment is in progress. Try again later."
          end
        end

        def resolutions(jobs)
          all_resolutions = {}
          jobs.each do |job, index|
            instance = @instance_manager.find_by_name(@deployment.name, job, index)
            next if instance.resurrection_paused
            problems = Models::DeploymentProblem.filter(deployment: @deployment, resource_id: instance.vm.id, state: 'open')
            problems.each do |problem|
              if problem.type == 'unresponsive_agent' || problem.type == 'missing_vm'
                all_resolutions[problem.id.to_s] = :recreate_vm
              end
            end
          end

          all_resolutions
        end

        def filtered_jobs
          return @jobs if @fix_stateful_jobs

          @jobs.reject do |job, index|
            instance = @instance_manager.find_by_name(@deployment.name, job, index)
            instance.persistent_disk
          end
        end
      end
    end
  end
end
