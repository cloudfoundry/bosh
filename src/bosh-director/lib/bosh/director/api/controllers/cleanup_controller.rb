require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class CleanupController < BaseController
      post '/', :consumes => :json do
        job_queue = JobQueue.new
        payload = json_decode(request.body.read)
        task = Bosh::Director::Jobs::CleanupArtifacts.enqueue(current_user, payload['config'], job_queue)

        redirect "/tasks/#{task.id}"
      end

      get '/dryrun' do
        cleanable_artifacts = Bosh::Director::CleanupArtifactManager.new(params[:remove_all] == 'true', logger).show_all
        JSON.generate(cleanable_artifacts)
      end
    end
  end
end
