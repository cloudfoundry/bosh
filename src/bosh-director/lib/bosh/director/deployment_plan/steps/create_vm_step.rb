module Bosh::Director
  module DeploymentPlan
    module Steps
      class CreateVmStep
        include PasswordHelper

        def initialize(instance_plan, agent_broadcaster, disks, tags = {}, use_existing = false)
          @instance_plan = instance_plan
          @agent_broadcaster = agent_broadcaster
          @disks = disks
          @use_existing = use_existing
          @tags = tags
          @logger = Config.logger
          @vm_deleter = VmDeleter.new(@logger, false, Config.enable_virtual_delete_vms)
          @variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new
        end

        def perform(report)
          instance = @instance_plan.instance

          cpi_factory, stemcell_model = choose_factory_and_stemcell_model(@instance_plan, @use_existing)

          instance_model = instance.model
          @logger.info('Creating VM')

          vm = create(
            instance,
            stemcell_model.cid,
            instance.cloud_properties,
            @instance_plan.network_settings_hash,
            @disks,
            instance.env,
            cpi_factory,
            stemcell_model.api_version
          )

          begin
            report.vm = vm
            update_metadata(@instance_plan, vm, cpi_factory)
          rescue Exception => e
            @logger.error("Failed to create/contact VM #{instance_model.vm_cid}: #{e.inspect}")
            if Config.keep_unreachable_vms
              @logger.info('Keeping the VM for debugging')
            else
              DeleteVmStep.new.perform(report)
            end
            raise e
          end
        end

        private

        def update_metadata(instance_plan, vm, factory)
          instance_model = instance_plan.instance.model
          MetadataUpdater.build.update_vm_metadata(instance_model, vm, @tags, factory)
          agent_client = AgentClient.with_agent_id(vm.agent_id)
          agent_client.wait_until_ready

          if Config.flush_arp
            ip_addresses = instance_plan.network_settings_hash.map do |index, network|
              network['ip']
            end.compact

            @agent_broadcaster.delete_arp_entries(vm.cid, ip_addresses)
          end
        end

        def choose_factory_and_stemcell_model(instance_plan, use_existing)
          deployment = instance_plan.instance.model.deployment

          if use_existing && !!instance_plan.existing_instance.availability_zone
            factory = AZCloudFactory.create_from_deployment(deployment)
            stemcell = instance_plan.instance.stemcell
            cpi = factory.get_name_for_az(instance_plan.existing_instance.availability_zone)
            stemcell_model = stemcell.models.find { |model| model.cpi == cpi }
            [factory, stemcell_model]
          else
            factory = AZCloudFactory.create_with_latest_configs(deployment)
            [factory, instance_plan.instance.stemcell_model]
          end
        end

        def create(instance, stemcell_cid, cloud_properties, network_settings, disks, env, cloud_factory, stemcell_api_version)
          instance_model = instance.model
          deployment_name = instance_model.deployment.name
          parent_id = add_event(deployment_name, instance_model.name, 'create')
          agent_id = SecureRandom.uuid


          config_server_client = ConfigServer::ClientFactory.create(@logger).create_client
          env = config_server_client.interpolate_with_versioning(env, instance.desired_variable_set)
          cloud_properties = config_server_client.interpolate_with_versioning(cloud_properties, instance.desired_variable_set)
          network_settings = config_server_client.interpolate_with_versioning(network_settings, instance.desired_variable_set)

          # TODO this is what we should use. However, there is a currently unexplained problem with in which manifests as:
=begin
Task 8 | 19:46:06 | Creating missing vms: zookeeper/e0b06ec7-f799-4837-8696-39b9a476bdb2 (4) (00:00:26)
                   L Error: - Unable to render templates for job 'zookeeper'. Errors are:
  wrong status line: "0"
Task 8 | 19:46:06 | Creating missing vms: zookeeper/51a68807-727b-4c71-b837-89eaf3faf520 (2) (00:00:26)
                   L Error: - Unable to render templates for job 'zookeeper'. Errors are:
  Bad file descriptor
Task 8 | 19:46:09 | Creating missing vms: zookeeper/ed72f006-786a-44ec-b885-8e210acf07ee (1) (00:00:29)
Task 8 | 19:46:09 | Creating missing vms: zookeeper/55b93f46-92f2-4afe-ae98-d3124af37ff7 (0) (00:00:29)
                   L Error: - Unable to render templates for job 'zookeeper'. Errors are:
  undefined method `closed?' for nil:NilClass
Task 8 | 19:46:09 | Creating missing vms: zookeeper/c3735152-cb45-4df0-a3c3-32a0e60c41ce (6) (00:00:29)
                   L Error: - Unable to render templates for job 'zookeeper'. Errors are:
  wrong status line: "0"
Task 8 | 19:46:09 | Creating missing vms: zookeeper/85661e99-1a32-4d6d-a587-eafdd488bb5c (8) (00:00:29)
                   L Error: - Unable to render templates for job 'zookeeper'. Errors are:
  undefined method `closed?' for nil:NilClass
Task 8 | 19:46:10 | Creating missing vms: zookeeper/dbd9c999-2810-4378-b862-ee88054fa34f (5) (00:00:30)
                   L Error: - Unable to render templates for job 'zookeeper'. Errors are:
  closed stream
=end

          # env = @variables_interpolator.interpolate_with_versioning(env, instance.desired_variable_set)
          # cloud_properties = @variables_interpolator.interpolate_with_versioning(cloud_properties, instance.desired_variable_set)
          # network_settings = @variables_interpolator.interpolate_with_versioning(network_settings, instance.desired_variable_set)

          cpi = cloud_factory.get_name_for_az(instance_model.availability_zone)

          vm_options = {instance: instance_model, agent_id: agent_id, cpi: cpi}

          env['bosh'] ||= {}
          env['bosh'] = Config.agent_env.merge(env['bosh'])

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
              "#{Bosh::Director::Config.name}-#{deployment_name}-#{instance_model.job}",
            ]
            env['bosh']['groups'].map! { |name| Canonicalizer.canonicalize(name) }
          end

          count = 0
          begin
            cloud = cloud_factory.get(vm_options[:cpi], stemcell_api_version)
            vm_cid = cloud.create_vm(agent_id, stemcell_cid, cloud_properties, network_settings, disks, env)
          rescue Bosh::Clouds::VMCreationFailed => e
            count += 1
            @logger.error("failed to create VM, retrying (#{count})")
            retry if e.ok_to_retry && count < Config.max_vm_create_tries
            raise e
          end

          vm_options[:cid] = vm_cid
          vm_options[:created_at] = Time.now
          vm_options[:stemcell_api_version] = stemcell_api_version
          vm_model = Models::Vm.create(vm_options)
          vm_model
        rescue => e
          @logger.error("error creating vm: #{e.message}")
          if vm_cid
            parent_id = add_event(deployment_name, instance_model.name, 'delete', vm_cid)
            @vm_deleter.delete_vm_by_cid(vm_cid, stemcell_api_version)
            add_event(deployment_name, instance_model.name, 'delete', vm_cid, parent_id)
          end
          raise e
        ensure
          add_event(deployment_name, instance_model.name, 'create', vm_cid, parent_id, e)
        end

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
              error: error,
            }
          )
          event.id
        end
      end
    end
  end
end
