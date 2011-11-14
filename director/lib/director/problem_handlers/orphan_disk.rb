module Bosh::Director
  module ProblemHandlers
    class OrphanDisk < Base

      register_as :orphan_disk
      auto_resolution :report

      def initialize(disk_id, data)
        super
        @disk_id = disk_id
        @data = data
        @disk = Models::PersistentDisk[disk_id]

        if @disk.nil?
          handler_error("Disk `#{@disk_id}' is no longer in the database")
        end
      end

      def problem_still_exists?
        !@disk.active
      end

      def description
        "Disk #{@disk.id} is orphan"
      end

      resolution :report do
        plan { "Report problem" }
        action { report }
      end

      resolution :delete_disk do
        plan { "Delete disk #{@disk.id}" }
        action { delete_disk }
      end

      def report
        # TODO
        true
      end

      def delete_disk
        @disk.destroy
        true
      end

    end
  end
end
