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
        begin
          instance = Bosh::Director::Api::InstanceLookup.new.by_vm_cid(@vm_cid).first
          @deployment_name = instance.deployment.name
          @instance_name = instance.name
          parent_id = add_event
          @vm_deleter.delete_for_instance(instance, false)
        rescue InstanceNotFound
          parent_id = add_event
          @vm_deleter.delete_vm_by_cid(@vm_cid)
        end
      rescue Bosh::Clouds::VMNotFound
        logger.info("vm #{@vm_cid} does not exists")
      rescue Exception => e
        raise e
      ensure
        add_event(parent_id, e)
        return "vm #{@vm_cid} deleted" unless e
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
