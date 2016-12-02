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

          resolved_problems = 0
          error_message = nil

          begin
            with_deployment_lock(@deployment, :timeout => 0) do

              scanner = ProblemScanner::Scanner.new(@deployment)
              scanner.reset(jobs)
              scanner.scan_vms(jobs)

              resolver = ProblemResolver.new(@deployment)
              resolved_problems, error_message = resolver.apply_resolutions(resolutions(jobs))

              if resolved_problems > 0
                PostDeploymentScriptRunner.run_post_deploys_after_resurrection(@deployment)
              end
            end

            if error_message
              raise Bosh::Director::ProblemHandlerError, error_message
            end

            'scan and fix complete'
          rescue Lock::TimeoutError
            raise 'Unable to get deployment lock, maybe a deployment is in progress. Try again later.'
          end
        end

        def resolutions(jobs)
          all_resolutions = {}
          jobs.each do |job, index|
            instance = @instance_manager.find_by_name(@deployment, job, index)
            next if instance.resurrection_paused || instance.ignore
            problems = Models::DeploymentProblem.filter(deployment: @deployment, resource_id: instance.id, state: 'open')
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
            instance = @instance_manager.find_by_name(@deployment, job, index)
            instance.active_persistent_disks.any?
          end
        end
      end
    end
  end
end
