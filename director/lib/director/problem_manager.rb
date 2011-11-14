module Bosh::Director

  class ProblemManager
    include TaskHelper

    def perform_scan(user, deployment_name)
      deployment = find_deployment(deployment_name)
      task = create_task(user, "scan cloud")
      Resque.enqueue(Jobs::CloudCheck::Scan, task.id, deployment.name)
      task
    end

    def get_problems(deployment_name)
      filters = { :deployment_id => find_deployment(deployment_name).id,  }
      Models::DeploymentProblem.filter(filters).order(:created_at).all
    end

    def apply_resolutions(user, deployment_name, resolutions)
      deployment = find_deployment(deployment_name)
      task = create_task(user, "apply resolutions")
      Resque.enqueue(Jobs::CloudCheck::ApplyResolutions, task.id, deployment.name, resolutions)
      task
    end

    private

    def find_deployment(name)
      deployment = Models::Deployment.find(:name => name)
      deployment || raise(DeploymentNotFound.new(name))
    end

  end
end
