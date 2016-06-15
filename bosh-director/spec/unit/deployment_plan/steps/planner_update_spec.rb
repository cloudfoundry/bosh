require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe 'deployment prepare & update' do

    before do
      allow(Bosh::Director::Config).to receive(:cloud).and_return(cloud)
    end

    context 'the director database contains an instance with a static ip but no vm assigned (due to deploy failure)' do
      before do
        release = Bosh::Director::Models::Release.make(name: 'fake-release')

        release_version = Bosh::Director::Models::ReleaseVersion.make(version: '1.0.0')
        release.add_version(release_version)

        template = Bosh::Director::Models::Template.make(name: 'fake-template')
        release_version.add_template(template)

        deployment.add_job_instance(instance_model)

      end

      let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'fake-deployment') }
      let(:instance_model) { Bosh::Director::Models::Instance.make(deployment: deployment, vm_cid: 'vm-cid-1')}
      let(:stemcell) { Bosh::Director::Models::Stemcell.make({ 'name' => 'fake-stemcell', 'version' => 'fake-stemcell-version'}) }

      context 'the agent on the existing VM has the requested static ip but no job instance assigned (due to deploy failure)' do
        before do
          allow(Bosh::Director::AgentClient).to receive(:with_vm_credentials_and_agent_id).and_return(agent_client)
          allow(agent_client).to receive(:apply)
          allow(agent_client).to receive(:drain).with('shutdown', {}).and_return(0)
          allow(agent_client).to receive(:stop)
          allow(agent_client).to receive(:wait_until_ready)
          allow(agent_client).to receive(:update_settings)
        end

        let(:agent_client) { instance_double('Bosh::Director::AgentClient') }

        before { allow(agent_client).to receive(:get_state).and_return(vm_state) }
        let(:vm_state) do
          {
            'deployment' => 'fake-deployment',
            'networks' => {
              'fake-network' => {
                'ip' => '127.0.0.1',
              },
            },
            'resource_pool' => {
              'name' => 'fake-resource-pool',
            },
            'index' => 0,
          }
        end

        context 'the new deployment manifest specifies 1 instance of a job with a static ip' do
          let(:update_step) { Steps::UpdateStep.new(base_job, deployment_plan, multi_job_updater, cloud) }

          let(:base_job) { Bosh::Director::Jobs::BaseJob.new }
          let(:multi_job_updater) { instance_double('Bosh::Director::DeploymentPlan::SerialMultiJobUpdater', run: nil) }
          let(:assembler) { Assembler.new(deployment_plan, nil, cloud, nil, logger) }
          let(:cloud_config) { nil }
          let(:runtime_config) { nil }

          let(:deployment_plan) do
            planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(logger)
            manifest = Bosh::Director::Manifest.new(deployment_manifest, nil, nil)
            deployment_plan = planner_factory.create_from_manifest(manifest, cloud_config, runtime_config, {})
            deployment_plan.bind_models
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

          let(:cloud) { instance_double('Bosh::Cloud') }

          let(:task) {Bosh::Director::Models::Task.make(:id => 42, :username => 'user')}
          before do
            allow(Bosh::Director::Config).to receive(:dns_enabled?).and_return(false)
            allow(base_job).to receive(:task_id).and_return(task.id)
            allow(Bosh::Director::Config).to receive(:current_job).and_return(base_job)
            allow(Bosh::Director::Config).to receive(:record_events).and_return(true)
          end

          before { allow(Bosh::Director::App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore) }
          let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

          before { allow_any_instance_of(Bosh::Director::JobRenderer).to receive(:render_job_instances) }
          before { allow_any_instance_of(Bosh::Director::JobRenderer).to receive(:render_job_instance) }

          it 'deletes the existing VM, and creates a new VM with the same IP' do
            expect(cloud).to receive(:delete_vm).ordered
            expect(cloud).to receive(:create_vm)
                               .with(anything, stemcell.cid, anything, { 'fake-network' => hash_including('ip' => '127.0.0.1') }, anything, anything)
                               .and_return('vm-cid-2')
                               .ordered

            update_step.perform
            expect(Bosh::Director::Models::Instance.find(vm_cid: 'vm-cid-1')).to be_nil
            expect(Bosh::Director::Models::Instance.find(vm_cid: 'vm-cid-2')).not_to be_nil
          end
        end
      end
    end
  end
end
