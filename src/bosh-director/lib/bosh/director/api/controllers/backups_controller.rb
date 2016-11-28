require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class BackupsController < BaseController
      post '/' do
        start_task { @backup_manager.create_backup(current_user) }
      end

      get '/' do
        send_file(@backup_manager.destination_path)
      end
    end
  end
end
