module Bosh::Director
  module Jobs
    class DeleteVm < BaseJob

      @queue = :normal

      def self.job_type
        :delete_vm
      end

      def initialize(vm_cid)
        @vm_cid = vm_cid
        @vm_deleter = Bosh::Director::VmDeleter.new(logger, false, false)
        @deployment_name = nil
        @instance_name = nil
      end

      def perform
        logger.info("deleting vm: #{@vm_cid}")
        event_log_stage = Config.event_log.begin_stage("Delete VM", 1)
        event_log_stage.advance_and_track(@vm_cid) do
          begin
            begin
              instance = Bosh::Director::Api::InstanceLookup.new.by_vm_cid(@vm_cid).first
              @deployment_name = instance.deployment.name
              @instance_name = instance.name
              parent_id = add_event
              @vm_deleter.delete_for_instance(instance, false)
              event_log_stage.advance_and_track("VM #{@vm_cid} is successfully deleted") {}
            rescue InstanceNotFound
              parent_id = add_event
              @vm_deleter.delete_vm_by_cid(@vm_cid)
              event_log_stage.advance_and_track("VM #{@vm_cid} is successfully deleted") {}
            end
          rescue Bosh::Clouds::VMNotFound
            logger.info("vm #{@vm_cid} does not exist")
            Config.event_log.warn("VM #{@vm_cid} does not exist. Deletion is skipped")
          rescue Exception => e
            raise e
          ensure
            add_event(parent_id, e)
            return "vm #{@vm_cid} deleted" unless e
          end
        end
      end

      private
      def add_event(parent_id = nil, error = nil)
        event = Config.current_job.event_manager.create_event(
            {
                parent_id: parent_id,
                user: Config.current_job.username,
                action: 'delete',
                object_type: 'vm',
                object_name: @vm_cid,
                task: Config.current_job.task_id,
                deployment: @deployment_name,
                instance: @instance_name,
                error: error
            })
        event.id
      end
    end
  end
end
