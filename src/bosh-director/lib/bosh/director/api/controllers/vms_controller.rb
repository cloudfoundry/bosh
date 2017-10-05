require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class VmsController < BaseController
      delete '/:vm_cid' do
        vm_cid = params[:vm_cid]
        task = JobQueue.new.enqueue(
          current_user,
          Jobs::DeleteVm,
          "delete vm #{vm_cid}",
          [vm_cid]
        )
        redirect "/tasks/#{task.id}"
      end
    end
  end
end
