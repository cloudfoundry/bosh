# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class ProblemManager
      include TaskHelper

      def initialize
        @deployment_manager = DeploymentManager.new
      end

      def perform_scan(user, deployment_name)
        deployment = @deployment_manager.find_by_name(deployment_name)
        task = create_task(user, :cck_scan, "scan cloud")

        Resque.enqueue(Jobs::CloudCheck::Scan, task.id, deployment.name)
        task
      end

      def get_problems(deployment_name)
        deployment = @deployment_manager.find_by_name(deployment_name)

        filters = {
          :deployment_id => deployment.id,
          :state => "open"
        }

        Models::DeploymentProblem.filter(filters).order(:created_at).all
      end

      def apply_resolutions(user, deployment_name, resolutions)
        deployment = @deployment_manager.find_by_name(deployment_name)
        task = create_task(user, :cck_apply, "apply resolutions")

        Resque.enqueue(Jobs::CloudCheck::ApplyResolutions, task.id, deployment.name, resolutions)
        task
      end

      def scan_and_fix(user, deployment_name, jobs)
        deployment = @deployment_manager.find_by_name(deployment_name)
        task = create_task(user, :cck_scan_and_fix, "scan and fix")

        Resque.enqueue(Jobs::CloudCheck::ScanAndFix, task.id, deployment.name, jobs)
        task
      end
    end
  end
end
