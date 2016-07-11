module Bosh::Director
  class VmDeleter
    def initialize(cloud, logger, force=false, enable_virtual_delete_vm=false)
      @cloud = cloud
      @logger = logger
      @error_ignorer = ErrorIgnorer.new(force, @logger)
      @enable_virtual_delete_vm = enable_virtual_delete_vm
    end

    def delete_for_instance(instance, store_event=true)
      if instance.vm_cid
        begin
          vm_cid = instance.vm_cid
          instance_name = "#{instance.job}/#{instance.uuid}"
          parent_id = add_event(instance.deployment.name, instance_name, vm_cid) if store_event
          delete_vm(instance.vm_cid)
          delete_local_dns_record(instance)
          instance.update(vm_cid: nil, agent_id: nil, trusted_certs_sha1: nil, credentials: nil)
        rescue Exception => e
          raise e
        ensure
          add_event(instance.deployment.name, instance_name, vm_cid, parent_id, e) if store_event
        end
      end
    end

    def delete_vm(vm_cid)
      @logger.info('Deleting VM')
      @error_ignorer.with_force_check do
        @cloud.delete_vm(vm_cid) unless @enable_virtual_delete_vm
      end
    end

    private

    def add_event(deployment_name, instance_name, object_name = nil, parent_id = nil, error = nil)
      event  = Config.current_job.event_manager.create_event(
          {
              parent_id:   parent_id,
              user:        Config.current_job.username,
              action:      'delete',
              object_type: 'vm',
              object_name: object_name,
              task:        Config.current_job.task_id,
              deployment:  deployment_name,
              instance:    instance_name,
              error:       error
          })
      event.id
    end

    def delete_local_dns_record(instance_model)
      spec = instance_model.spec
      @logger.debug('Deleting local dns records')
      unless spec.nil? || spec['networks'].nil?
        @logger.debug("Found #{spec['networks'].length} networks")
        spec['networks'].each do |network_name, network|
          unless network['ip'].nil? or spec['job'].nil?
            ip = network['ip']
            name = instance_model.uuid + '.' + spec['job']['name'] + '.' + network_name + '.' + spec['deployment'] + '.' + Config.canonized_dns_domain_name
            @logger.debug("Removing local dns record with name #{name} and ip #{ip}")
            Bosh::Director::Config.db.transaction(:isolation => :repeatable, :retry_on=>[Sequel::SerializationFailure]) do
              Models::LocalDnsRecord.where(:name => name, :ip => ip, :instance_id => instance_model.id ).delete
            end
          end
        end
      end
    end
  end
end
