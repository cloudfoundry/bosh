module Bosh::Director
  module Api
    class ProblemManager
      def perform_scan(username, deployment)
        JobQueue.new.enqueue(username, Jobs::CloudCheck::Scan, 'scan cloud', [deployment.name], deployment)
      end

      def get_problems(deployment)
        filters = {
          :deployment_id => deployment.id,
          :state => 'open'
        }

        Models::DeploymentProblem.filter(filters).order(:created_at).all
      end

      def apply_resolutions(username, deployment, resolutions, max_in_flight_overrides)
        JobQueue.new.enqueue(username, Jobs::CloudCheck::ApplyResolutions, 'apply resolutions', [deployment.name, resolutions, max_in_flight_overrides], deployment)
      end

      def scan_and_fix(username, deployment, jobs)
        JobQueue.new.enqueue(username, Jobs::CloudCheck::ScanAndFix, 'scan and fix', [deployment.name, jobs, Bosh::Director::Config.fix_stateful_nodes], deployment)
      end
    end
  end
end
