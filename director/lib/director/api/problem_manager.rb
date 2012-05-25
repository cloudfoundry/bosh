# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class ProblemManager
      include TaskHelper

      def perform_scan(user, deployment_name)
        deployment = find_deployment(deployment_name)
        task = create_task(user, :cck_scan, "scan cloud")
        Resque.enqueue(Jobs::CloudCheck::Scan, task.id, deployment.name)
        task
      end

      def get_problems(deployment_name)
        filters = {:deployment_id => find_deployment(deployment_name).id,
                   :state => "open"}
        Models::DeploymentProblem.filter(filters).order(:created_at).all
      end

      def apply_resolutions(user, deployment_name, resolutions)
        deployment = find_deployment(deployment_name)
        task = create_task(user, :cck_apply, "apply resolutions")
        Resque.enqueue(Jobs::CloudCheck::ApplyResolutions, task.id,
                       deployment.name, resolutions)
        task
      end

      private

      def find_deployment(name)
        deployment = Models::Deployment.find(:name => name)
        deployment || raise(DeploymentNotFound.new(name))
      end
    end
  end
end
