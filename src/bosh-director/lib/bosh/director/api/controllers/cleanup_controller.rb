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
    end
  end
end
