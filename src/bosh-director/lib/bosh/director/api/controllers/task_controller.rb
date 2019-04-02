require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class TaskController < BaseController
      delete '/:id' do
        task_id = params[:id]
        task = @task_manager.find_task(task_id)
        begin
          @task_manager.cancel(task)
          status(204)
        rescue TaskUnexpectedState
          body("Cannot cancel task #{task_id}: invalid state (#{task.state})")
          status(400)
        end
      end
    end
  end
end
