require 'common/deep_copy'
require 'securerandom'

module Bosh::Director
  # Creates VM model and call out to CPI to create VM in IaaS
  class VmCreator
    include EncryptionHelper
    include PasswordHelper

    def initialize(cloud, logger, vm_deleter, disk_manager, job_renderer, arp_flusher)
      @cloud = cloud
      @logger = logger
      @vm_deleter = vm_deleter
      @disk_manager = disk_manager
      @job_renderer = job_renderer
      @arp_flusher = arp_flusher
    end

    def create_for_instance_plans(instance_plans, ip_provider)
      return @logger.info('No missing vms to create') if instance_plans.empty?

      total = instance_plans.size
      event_log_stage = Config.event_log.begin_stage('Creating missing vms', total)
      ThreadPool.new(max_threads: Config.max_threads, logger: @logger).wrap do |pool|
        instance_plans.each do |instance_plan|
          instance = instance_plan.instance

          pool.process do
            with_thread_name("create_missing_vm(#{instance.model}/#{total})") do
              event_log_stage.advance_and_track(instance.model.to_s) do
                @logger.info('Creating missing VM')
                disks = [instance.model.persistent_disk_cid].compact
                create_for_instance_plan(instance_plan, disks)

                instance_plan.network_plans
                  .select(&:obsolete?)
                  .each do |network_plan|
                  reservation = network_plan.reservation
                  ip_provider.release(reservation)
                end
                instance_plan.release_obsolete_network_plans
              end
            end
          end
        end
      end
    end

    def create_for_instance_plan(instance_plan, disks)
      instance = instance_plan.instance
      instance_model = instance.model
      @logger.info('Creating VM')

      create(
        instance_model,
        instance.stemcell,
        instance.cloud_properties,
        instance_plan.network_settings_hash,
        disks,
        instance.env,
      )

      begin
        VmMetadataUpdater.build.update(instance_model, {})
        agent_client = AgentClient.with_vm_credentials_and_agent_id(instance_model.credentials, instance_model.agent_id)
        agent_client.wait_until_ready

        if Config.flush_arp
          ip_addresses = instance_plan.network_settings_hash.map do |index,network|
            network['ip']
          end.compact

          @arp_flusher.delete_arp_entries(instance_model.vm_cid, ip_addresses)
        end

        instance.update_trusted_certs
        instance.update_cloud_properties!
      rescue Exception => e
        @logger.error("Failed to create/contact VM #{instance_model.vm_cid}: #{e.inspect}")
        if Config.keep_unreachable_vms
          @logger.info('Keeping the VM for debugging')
        else
          @vm_deleter.delete_for_instance(instance_model)
        end
        raise e
      end

      @disk_manager.attach_disks_if_needed(instance_plan)

      apply_initial_vm_state(instance_plan)

      instance_plan.mark_desired_network_plans_as_existing
    end

    private

    def add_event(deployment_name, instance_name, action, object_name = nil, parent_id = nil, error = nil)
      event = Config.current_job.event_manager.create_event(
          {
              parent_id:   parent_id,
              user:        Config.current_job.username,
              action:      action,
              object_type: 'vm',
              object_name: object_name,
              task:        Config.current_job.task_id,
              deployment:  deployment_name,
              instance:    instance_name,
              error:       error
          })
      event.id
    end

    def apply_initial_vm_state(instance_plan)
      instance_plan.instance.apply_initial_vm_state(instance_plan.spec)

      unless instance_plan.instance.compilation?
        # re-render job templates with updated dynamic network settings
        @logger.debug("Re-rendering templates with spec: #{instance_plan.spec.as_template_spec}")
        @job_renderer.render_job_instance(instance_plan)
      end
    end

    def create(instance_model, stemcell, cloud_properties, network_settings, disks, env)
      parent_id = add_event(instance_model.deployment.name, instance_model.name, 'create')
      agent_id = self.class.generate_agent_id
      env = Bosh::Common::DeepCopy.copy(env)
      options = {:agent_id => agent_id}

      if Config.encryption?
        credentials = generate_agent_credentials
        env['bosh'] ||= {}
        env['bosh']['credentials'] = credentials
        options[:credentials] = credentials
      end

      password = env.fetch('bosh', {}).fetch('password', "")
      if Config.generate_vm_passwords && password == ""
        env['bosh'] ||= {}
        env['bosh']['password'] = sha512_hashed_password
      end

      count = 0
      begin
        vm_cid = @cloud.create_vm(agent_id, stemcell.cid, cloud_properties, network_settings, disks, env)
      rescue Bosh::Clouds::VMCreationFailed => e
        count += 1
        @logger.error("failed to create VM, retrying (#{count})")
        retry if e.ok_to_retry && count < Config.max_vm_create_tries
        raise e
      end

      options[:vm_cid] = vm_cid

      instance_model.update(options)
    rescue => e
      @logger.error("error creating vm: #{e.message}")
      if vm_cid
        parent_id = add_event(instance_model.deployment.name, instance_model.name, 'delete', vm_cid)
        @vm_deleter.delete_vm(vm_cid)
        add_event(instance_model.deployment.name, instance_model.name, 'delete', vm_cid, parent_id)
      end
      raise e
    ensure
      add_event(instance_model.deployment.name, instance_model.name, 'create', vm_cid, parent_id, e)
    end

    def self.generate_agent_id
      SecureRandom.uuid
    end
  end
end
