#module Bosh::Director
#  module Jobs
#    class BackupCreate < BaseJob
#
#      @queue = :normal
#
#      def perform
#        logger.info "Starting a new backup..."
#        filename = Bosh::Director::Api::BackupManager.new(nil).create!
#        logger.info "Backup [ #{filename} ] done."
#        filename
#      end
#    end
#  end
#end
