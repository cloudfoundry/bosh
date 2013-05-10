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

        def initialize(deployment_name, jobs)
          @deployment_manager = Api::DeploymentManager.new
          @instance_manager = Bosh::Director::Api::InstanceManager.new
          @deployment = @deployment_manager.find_by_name(deployment_name)
          @jobs = jobs # {j1 => [i1, i2, ...], j2 => [i1, i2, ...]}
          @filtered_jobs = {}
        end

        def perform
          filter_out_jobs_with_persistent_disks
          begin
            with_deployment_lock(@deployment, :timeout => 0) do

              scanner = ProblemScanner.new(@deployment)
              scanner.reset(@filtered_jobs)
              scanner.scan_vms(@filtered_jobs)

              resolver = ProblemResolver.new(@deployment)
              # TODO the application for resolutions should be done using a thread pool
              resolver.apply_resolutions(resolutions)

              "scan and fix complete"
            end
          rescue Lock::TimeoutError
            raise "Unable to get deployment lock, maybe a deployment is in progress. Try again later."
          end
        end

        def resolutions
          all_resolutions = {}
          @filtered_jobs.each do |job, indices|
            indices.each do |index|
              instance = @instance_manager.find_by_name(@deployment.name, job, index)

              problems = Models::DeploymentProblem.filter(deployment: @deployment, resource_id: instance.vm.id, state: 'open')
              problems.each do |problem|
                if problem.type == 'unresponsive_agent' || problem.type == 'missing_vm'
                  all_resolutions[problem.id.to_s] = :recreate_vm
                end
              end
            end
          end

          all_resolutions
        end

        def filter_out_jobs_with_persistent_disks
          @jobs.each do |job, indices|
            @filtered_jobs[job] = indices.reject do |index|
              instance = @instance_manager.find_by_name(@deployment.name, job, index)
              instance.persistent_disk
            end
          end
        end
      end
    end
  end
end
