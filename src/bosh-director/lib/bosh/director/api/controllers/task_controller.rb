require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class TaskController < BaseController
      delete '/:id' do
        task_id = params[:id]
        task = @task_manager.find_task(task_id)
        if task.state != 'processing' && task.state != 'queued'
          status(400)
          body("Cannot cancel task #{task_id}: invalid state (#{task.state})")
        else
          task.state = :cancelling
          task.save
          status(204)
        end
      end
    end
  end
end
