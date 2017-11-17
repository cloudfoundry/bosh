require 'spec_helper'

module Bosh::Director::DeploymentPlan::Steps
  describe 'deployment prepare & update', truncation: true, :if => ENV.fetch('DB', 'sqlite') != 'sqlite' do
    before do
      release = Bosh::Director::Models::Release.make(name: 'fake-release')

      release_version = Bosh::Director::Models::ReleaseVersion.make(version: '1.0.0')
      release.add_version(release_version)

      template = Bosh::Director::Models::Template.make(name: 'fake-template')
      release_version.add_template(template)
    end

    let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'fake-deployment') }
    let!(:stemcell) { Bosh::Director::Models::Stemcell.make({'name' => 'fake-stemcell', 'version' => 'fake-stemcell-version'}) }

    before do
      allow(Bosh::Director::AgentClient).to receive(:with_agent_id).and_return(agent_client)
      allow(agent_client).to receive(:apply)
      allow(agent_client).to receive(:drain).and_return(0)
      allow(agent_client).to receive(:stop)
      allow(agent_client).to receive(:wait_until_ready)
      allow(agent_client).to receive(:update_settings)
      allow(agent_client).to receive(:get_state)
    end

    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
    let(:dns_encoder) { Bosh::Director::DnsEncoder.new({}) }
    let(:update_step) { UpdateStep.new(base_job, deployment_plan, multi_job_updater, dns_encoder) }

    let(:base_job) { Bosh::Director::Jobs::BaseJob.new }
    let(:assembler) { Assembler.new(deployment_plan, nil, nil) }
    let(:cloud_config) { nil }
    let(:runtime_configs) { [] }

    let(:deployment_plan) do
      planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(logger)
      manifest = Bosh::Director::Manifest.new(deployment_manifest, YAML.dump(deployment_manifest), nil, nil)
      deployment_plan = planner_factory.create_from_manifest(manifest, cloud_config, runtime_configs, {})
      Bosh::Director::DeploymentPlan::Assembler.create(deployment_plan).bind_models
      deployment_plan
    end
    let(:deployment_manifest) do
      {
        'name' => 'fake-deployment',
        'jobs' => [
          {
            'name' => 'fake-job',
            'templates' => [
              {
                'name' => 'fake-template',
                'release' => 'fake-release',
              }
            ],
            'resource_pool' => 'fake-resource-pool',
            'instances' => 1,
            'networks' => [
              {
                'name' => 'fake-network',
                'static_ips' => ['127.0.0.1']
              }
            ],
          }
        ],
        'resource_pools' => [
          {
            'name' => 'fake-resource-pool',
            'size' => 1,
            'cloud_properties' => {},
            'stemcell' => {
              'name' => 'fake-stemcell',
              'version' => 'fake-stemcell-version',
            },
            'network' => 'fake-network',
            'jobs' => []
          }
        ],
        'networks' => [
          {
            'name' => 'fake-network',
            'type' => 'manual',
            'cloud_properties' => {},
            'subnets' => [
              {
                'name' => 'fake-subnet',
                'range' => '127.0.0.0/20',
                'gateway' => '127.0.0.2',
                'cloud_properties' => {},
                'static' => ['127.0.0.1'],
              }
            ]
          }
        ],
        'releases' => [
          {
            'name' => 'fake-release',
            'version' => '1.0.0',
          }
        ],
        'compilation' => {
          'workers' => 1,
          'network' => 'fake-network',
          'cloud_properties' => {},
        },
        'update' => {
          'canaries' => 1,
          'max_in_flight' => 1,
          'canary_watch_time' => 1,
          'update_watch_time' => 1,
        },
      }
    end

    let(:cloud) { Bosh::Director::Config.cloud }

    let(:task) { Bosh::Director::Models::Task.make(:id => 42, :username => 'user') }
    let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, task.id) }
    let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }
    before do
      Bosh::Director::Models::VariableSet.make(deployment: deployment)
      allow(base_job).to receive(:task_id).and_return(task.id)
      allow(Bosh::Director::Config).to receive(:current_job).and_return(base_job)
      allow(Bosh::Director::Config).to receive(:record_events).and_return(true)
      allow(Bosh::Director::Config).to receive(:name).and_return('fake-director-name')
      allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
    end

    before { allow(Bosh::Director::App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore) }
    let(:blobstore) { instance_double(Bosh::Blobstore::Sha1VerifiableBlobstoreClient) }

    before { allow(blobstore).to receive(:get) }
    before { allow(Bosh::Director::JobRenderer).to receive(:render_job_instances_with_cache) }

    context 'the director database contains an instance with a static ip but no vm assigned (due to deploy failure)' do
      let(:instance_model) do
        instance = Bosh::Director::Models::Instance.make(deployment: deployment)
        Bosh::Director::Models::Vm.make(cid: 'vm-cid-1', instance: instance, active: true)
        instance
      end

      context 'the agent on the existing VM has the requested static ip but no job instance assigned (due to deploy failure)' do
        context 'the new deployment manifest specifies 1 instance of a job with a static ip' do
          let(:multi_job_updater) { instance_double('Bosh::Director::DeploymentPlan::SerialMultiJobUpdater', run: nil) }
          before do
            deployment.add_job_instance(instance_model)
          end
          it 'deletes the existing VM, and creates a new VM with the same IP' do
            expect(cloud).to receive(:delete_vm).ordered
            expect(cloud).to receive(:create_vm)
                               .with(anything, stemcell.cid, anything, {'fake-network' => hash_including('ip' => '127.0.0.1')}, anything, anything)
                               .and_return('vm-cid-2')
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
      let(:multi_job_updater) do
        Bosh::Director::DeploymentPlan::SerialMultiJobUpdater.new(
          Bosh::Director::JobUpdaterFactory.new(logger, deployment_plan.template_blob_cache, dns_encoder)
        )
      end

      before do
        allow(agent_client).to receive(:get_state).and_return({'job_state' => 'running'})
        allow(agent_client).to receive(:prepare)
        allow(agent_client).to receive(:run_script)
        allow(agent_client).to receive(:start)
        allow(cloud).to receive(:create_vm).and_return('vm-cid-2').ordered
      end

      it "creates an instance with 'lifecycle' in the spec" do
        update_step.perform

        vm = Bosh::Director::Models::Vm.find(cid: 'vm-cid-2')
        expect(Bosh::Director::Models::Instance.all.select { |i| i.active_vm = vm }.first.spec['lifecycle']).to eq('service')
      end
    end
  end
end
