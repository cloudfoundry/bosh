require 'spec_helper'

module Bosh::Director::DeploymentPlan::Stages
  describe 'deployment prepare & update', truncation: true, :if => ENV.fetch('DB', 'sqlite') != 'sqlite' do
    let(:deployment) { FactoryBot.create(:models_deployment, name: deployment_manifest['name']) }
    let!(:stemcell) { FactoryBot.create(:models_stemcell, 'name' => 'ubuntu-stemcell', 'version' => '1') }

    let(:agent_client) { instance_double(Bosh::Director::AgentClient) }
    let(:dns_encoder) { Bosh::Director::DnsEncoder.new({}) }
    let(:link_provider_intents) { [] }
    let(:update_step) do
      UpdateStage.new(base_job, deployment_plan, multi_instance_group_updater, dns_encoder, link_provider_intents)
    end

    let(:base_job) { Bosh::Director::Jobs::BaseJob.new }
    let(:assembler) { Assembler.new(deployment_plan, nil, nil, variables_interpolator) }
    let(:cloud_config) { Bosh::Spec::Deployments.simple_cloud_config }
    let(:runtime_configs) { [] }

    let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }

    let(:deployment_plan) do
      planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(logger)
      manifest = Bosh::Director::Manifest.new(deployment_manifest, YAML.dump(deployment_manifest), cloud_config, nil)
      deployment_plan = planner_factory.create_from_manifest(manifest, nil, runtime_configs, {})
      Bosh::Director::DeploymentPlan::Assembler.create(deployment_plan, variables_interpolator).bind_models
      deployment_plan
    end
    let(:static_ip) { Bosh::Spec::Deployments.subnet['static'].first }
    let(:deployment_manifest) do
      Bosh::Spec::Deployments.simple_manifest_with_instance_groups(instances: 1, static_ips: static_ip)
    end
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpiResponseWrapper) }

    let(:task) { FactoryBot.create(:models_task, id: 42, username: 'user') }
    let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, task.id) }
    let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }
    let(:blobstore) { instance_double(Bosh::Blobstore::Sha1VerifiableBlobstoreClient) }

    before do
      release = FactoryBot.create(:models_release, name: 'bosh-release')
      release_version = FactoryBot.create(:models_release_version, version: '0.1-dev')
      release.add_version(release_version)
      template = FactoryBot.create(:models_template,
        name: Bosh::Spec::Deployments.simple_instance_group['jobs'].first['name'],
      )
      release_version.add_template(template)

      allow(Bosh::Director::AgentClient).to receive(:with_agent_id).and_return(agent_client)
      allow(agent_client).to receive(:apply)
      allow(agent_client).to receive(:drain).and_return(0)
      allow(agent_client).to receive(:stop)
      allow(agent_client).to receive(:run_script).with(
        'pre-stop',
        'env' => {
          'BOSH_VM_NEXT_STATE' => 'delete',
          'BOSH_INSTANCE_NEXT_STATE' => 'delete',
          'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
        },
      )
      allow(agent_client).to receive(:run_script).with('post-stop', {})
      allow(agent_client).to receive(:wait_until_ready)
      allow(agent_client).to receive(:update_settings)
      allow(agent_client).to receive(:get_state)

      Bosh::Director::Models::VariableSet.make(deployment: deployment)
      allow(base_job).to receive(:task_id).and_return(task.id)
      allow(Bosh::Director::Config).to receive(:current_job).and_return(base_job)
      allow(Bosh::Director::Config).to receive(:record_events).and_return(true)
      allow(Bosh::Director::Config).to receive(:name).and_return('fake-director-name')
      allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
      allow(Bosh::Director::Config).to receive(:uuid).and_return('meow-uuid')
      allow(Bosh::Director::Config).to receive(:cloud_options).and_return('provider' => { 'path' => '/path/to/default/cpi' })
      allow(Bosh::Director::Config).to receive(:preferred_cpi_api_version).and_return(1)
      allow(Bosh::Director::Config).to receive(:enable_short_lived_nats_bootstrap_credentials).and_return(true)
      director_config = SpecHelper.spec_get_director_config
      allow(Bosh::Director::Config).to receive(:nats_client_ca_private_key_path).and_return(director_config['nats']['client_ca_private_key_path'])
      allow(Bosh::Director::Config).to receive(:nats_client_ca_certificate_path).and_return(director_config['nats']['client_ca_certificate_path'])
      allow(Bosh::Clouds::ExternalCpiResponseWrapper).to receive(:new).with(anything, anything).and_return(cloud)
      allow(variables_interpolator).to receive(:interpolate_template_spec_properties).and_return({})
      allow(variables_interpolator).to receive(:interpolated_versioned_variables_changed?).and_return(false)

      allow(Bosh::Director::App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
      allow(blobstore).to receive(:get)
      allow(Bosh::Director::JobRenderer).to receive(:render_job_instances_with_cache)
      allow(blobstore).to receive(:can_sign_urls?).and_return(false)
      allow(blobstore).to receive(:validate!)
    end

    context 'the director database contains an instance with a static ip but no vm assigned (due to deploy failure)' do
      let(:instance_model) do
        instance = Bosh::Director::Models::Instance.make(deployment: deployment)
        Bosh::Director::Models::Vm.make(cid: 'vm-cid-1', instance: instance, active: true)
        instance
      end

      context 'the agent on the existing VM has the requested static ip but no job instance assigned (due to deploy failure)' do
        context 'the new deployment manifest specifies 1 instance of a job with a static ip' do
          let(:multi_instance_group_updater) do
            instance_double('Bosh::Director::DeploymentPlan::SerialMultiInstanceGroupUpdater', run: nil)
          end

          before do
            deployment.add_job_instance(instance_model)
          end

          it 'deletes the existing VM, and creates a new VM with the same IP' do
            expect(cloud).to receive(:delete_vm).ordered
            expect(cloud).to receive(:create_vm)
              .with(
                anything,
                stemcell.cid,
                anything,
                { Bosh::Spec::Deployments.network['name'] => hash_including('ip' => static_ip) },
                anything,
                anything,
              )
              .and_return(['vm-cid-2'])
              .ordered

            update_step.perform
            expect(Bosh::Director::Models::Vm.find(cid: 'vm-cid-1')).to be_nil
            vm2 = Bosh::Director::Models::Vm.find(cid: 'vm-cid-2')
            expect(vm2).not_to be_nil
            expect(Bosh::Director::Models::Instance.all.select { |i| i.active_vm = vm2 }.first).not_to be_nil

            expect(agent_client).to have_received(:drain).with('shutdown', {})
          end
        end
      end
    end

    context 'when the director database contains no instances' do
      let(:multi_instance_group_updater) do
        Bosh::Director::DeploymentPlan::SerialMultiInstanceGroupUpdater.new(
          Bosh::Director::InstanceGroupUpdaterFactory.new(
            logger,
            deployment_plan.template_blob_cache,
            dns_encoder,
            link_provider_intents,
          ),
        )
      end

      before do
        allow(agent_client).to receive(:get_state).and_return('job_state' => 'running')
        allow(agent_client).to receive(:prepare)
        allow(agent_client).to receive(:run_script)
        allow(agent_client).to receive(:start)
        allow(cloud).to receive(:create_vm).and_return(['vm-cid-2'])
      end

      it "creates an instance with 'lifecycle' in the spec" do
        update_step.perform

        vm = Bosh::Director::Models::Vm.find(cid: 'vm-cid-2')
        expect(Bosh::Director::Models::Instance.all.select { |i| i.active_vm = vm }.first.spec['lifecycle']).to eq('service')
      end
    end
  end
end
