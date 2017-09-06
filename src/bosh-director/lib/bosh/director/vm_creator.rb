require 'common/deep_copy'
require 'securerandom'

module Bosh::Director
  # Creates VM model and call out to CPI to create VM in IaaS
  class VmCreator
    include PasswordHelper

    def initialize(logger, vm_deleter, disk_manager, template_blob_cache, dns_encoder, agent_broadcaster)
      @logger = logger
      @vm_deleter = vm_deleter
      @disk_manager = disk_manager
      @template_blob_cache = template_blob_cache
      @dns_encoder = dns_encoder
      @agent_broadcaster = agent_broadcaster

      @config_server_client_factory = Bosh::Director::ConfigServer::ClientFactory.create(@logger)
    end

    def create_for_instance_plans(instance_plans, ip_provider, tags={})
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
                disks = [instance.model.managed_persistent_disk_cid].compact
                create_for_instance_plan(instance_plan, disks, tags)
                instance_plan.release_obsolete_network_plans(ip_provider)
              end
            end
          end
        end
      end
    end

    def create_for_instance_plan(instance_plan, disks, tags, use_existing=false)
      instance = instance_plan.instance

      factory, stemcell_cid = choose_factory_and_stemcell_cid(instance_plan, use_existing)

      instance_model = instance.model
      @logger.info('Creating VM')

      create(
        instance,
        stemcell_cid,
        instance.cloud_properties,
        instance_plan.network_settings_hash,
        disks,
        instance.env,
        factory
      )

      begin
        MetadataUpdater.build.update_vm_metadata(instance_model, tags, factory)
        agent_client = AgentClient.with_agent_id(instance_model.agent_id)
        agent_client.wait_until_ready

        if Config.flush_arp
          ip_addresses = instance_plan.network_settings_hash.map do |index, network|
            network['ip']
          end.compact

          @agent_broadcaster.delete_arp_entries(instance_model.vm_cid, ip_addresses)
        end

        @disk_manager.attach_disks_if_needed(instance_plan)

        instance.update_instance_settings
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

      apply_initial_vm_state(instance_plan)

      instance_plan.mark_desired_network_plans_as_existing
    end

    private

    def add_event(deployment_name, instance_name, action, object_name = nil, parent_id = nil, error = nil)
      event = Config.current_job.event_manager.create_event(
        {
          parent_id: parent_id,
          user: Config.current_job.username,
          action: action,
          object_type: 'vm',
          object_name: object_name,
          task: Config.current_job.task_id,
          deployment: deployment_name,
          instance: instance_name,
          error: error
        })
      event.id
    end

    def apply_initial_vm_state(instance_plan)
      instance_plan.instance.apply_initial_vm_state(instance_plan.spec)

      unless instance_plan.instance.compilation?
        # re-render job templates with updated dynamic network settings
        @logger.debug("Re-rendering templates with updated dynamic networks: #{instance_plan.spec.as_template_spec['networks']}")
        JobRenderer.render_job_instances_with_cache([instance_plan], @template_blob_cache, @dns_encoder, @logger)
      end
    end

    def choose_factory_and_stemcell_cid(instance_plan, use_existing)
      if use_existing && !!instance_plan.existing_instance.availability_zone
        factory = CloudFactory.create_from_deployment(instance_plan.existing_instance.deployment)

        stemcell = instance_plan.instance.stemcell
        cpi = factory.get_name_for_az(instance_plan.existing_instance.availability_zone)
        stemcell_cid = stemcell.models.find { |model| model.cpi == cpi }.cid
        return factory, stemcell_cid
      else
        return CloudFactory.create_with_latest_configs, instance_plan.instance.stemcell_cid
      end
    end

    def create(instance, stemcell_cid, cloud_properties, network_settings, disks, env, factory)
      instance_model = instance.model
      deployment_name = instance_model.deployment.name
      parent_id = add_event(deployment_name, instance_model.name, 'create')
      agent_id = self.class.generate_agent_id

      config_server_client = @config_server_client_factory.create_client
      env = config_server_client.interpolate_with_versioning(env, instance.desired_variable_set)
      cloud_properties = config_server_client.interpolate_with_versioning(cloud_properties, instance.desired_variable_set)
      network_settings = config_server_client.interpolate_with_versioning(network_settings, instance.desired_variable_set)

      cpi = factory.get_name_for_az(instance_model.availability_zone)

      vm_options = {instance: instance_model, agent_id: agent_id, cpi: cpi}
      options = {}

      if Config.nats_uri
        env['bosh'] ||= {}
        env['bosh']['mbus'] ||= {}
        env['bosh']['mbus']['urls'] = [ Config.nats_uri ]
      end

      if Config.nats_server_ca
        env['bosh'] ||= {}
        env['bosh']['mbus'] ||= {}
        env['bosh']['mbus']['cert'] ||= {}
        env['bosh']['mbus']['cert']['ca'] = Config.nats_server_ca
        cert_generator = NatsClientCertGenerator.new(@logger)
        agent_cert_key_result = cert_generator.generate_nats_client_certificate "#{agent_id}.agent.bosh-internal"
        env['bosh']['mbus']['cert']['certificate'] = agent_cert_key_result[:cert].to_pem
        env['bosh']['mbus']['cert']['private_key'] = agent_cert_key_result[:key].to_pem
      end

      password = env.fetch('bosh', {}).fetch('password', "")
      if Config.generate_vm_passwords && password == ""
        env['bosh'] ||= {}
        env['bosh']['password'] = sha512_hashed_password
      end

      if instance_model.job
        env['bosh'] ||= {}
        env['bosh']['group'] = Canonicalizer.canonicalize("#{Bosh::Director::Config.name}-#{deployment_name}-#{instance_model.job}")
        env['bosh']['groups'] = [
          Bosh::Director::Config.name,
          deployment_name,
          instance_model.job,
          "#{Bosh::Director::Config.name}-#{deployment_name}",
          "#{deployment_name}-#{instance_model.job}",
          "#{Bosh::Director::Config.name}-#{deployment_name}-#{instance_model.job}"
        ]
        env['bosh']['groups'].map! { |name| Canonicalizer.canonicalize(name) }
      end

      count = 0
      begin
        cloud = factory.get(vm_options[:cpi])
        vm_cid = cloud.create_vm(agent_id, stemcell_cid, cloud_properties, network_settings, disks, env)
      rescue Bosh::Clouds::VMCreationFailed => e
        count += 1
        @logger.error("failed to create VM, retrying (#{count})")
        retry if e.ok_to_retry && count < Config.max_vm_create_tries
        raise e
      end

      vm_options[:cid] = vm_cid
      vm_options[:created_at] = Time.now
      vm_model = Models::Vm.create(vm_options)
      vm_model.save

      unless instance.vm_created?
        instance_model.active_vm = vm_model
      end

      instance_model.update(options)
    rescue => e
      @logger.error("error creating vm: #{e.message}")
      if vm_cid
        parent_id = add_event(deployment_name, instance_model.name, 'delete', vm_cid)
        @vm_deleter.delete_vm_by_cid(vm_cid)
        add_event(deployment_name, instance_model.name, 'delete', vm_cid, parent_id)
      end
      raise e
    ensure
      add_event(deployment_name, instance_model.name, 'create', vm_cid, parent_id, e)
    end

    def self.generate_agent_id
      SecureRandom.uuid
    end
  end
end
