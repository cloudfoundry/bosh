require 'json'
require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class ErrandsController < BaseController
      get '/deployments/:deployment_name/errands' do
        deployment = @deployment_manager.find_by_name(params[:deployment_name])

        manifest = Psych.load(deployment.manifest)
        deployment_plan = DeploymentPlan::Planner.parse(manifest, {}, Config.event_log, Config.logger)

        errands = deployment_plan.jobs.select(&:can_run_as_errand?)

        errand_data = errands.map do |errand| 
          { "name" => errand.name }
        end

        json_encode(errand_data)
      end

      post '/deployments/:deployment_name/errands/:errand_name/runs' do
        deployment_name = params[:deployment_name]
        errand_name = params[:errand_name]

        task = JobQueue.new.enqueue(
          @user,
          Jobs::RunErrand,
          "run errand #{errand_name} from deployment #{deployment_name}",
          [deployment_name, errand_name],
        )

        redirect "/tasks/#{task.id}"
      end

      def body_params
        @body_params ||= JSON.load(request.body)
      end
    end
  end
end
