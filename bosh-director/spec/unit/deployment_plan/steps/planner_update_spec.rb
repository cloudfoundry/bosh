require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe 'deployment prepare & update' do
    let(:redis) { double('Redis').as_null_object }
    before { allow(Bosh::Director::Config).to receive(:redis).and_return(redis) }
    let(:event_log) { Bosh::Director::Config.event_log }

    before do
      allow(Bosh::Director::Config).to receive(:logger).and_return(logger)
      allow(Bosh::Director::Config).to receive(:cloud).and_return(cloud)
    end

    context 'the director database contains a VM with a static ip but no job instance assigned (due to deploy failure)' do
      before do
        release = Bosh::Director::Models::Release.make(name: 'fake-release')

        release_version = Bosh::Director::Models::ReleaseVersion.make(version: '1.0.0')
        release.add_version(release_version)

        template = Bosh::Director::Models::Template.make(name: 'fake-template')
        release_version.add_template(template)

        deployment.add_vm(vm_model)
      end

      let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'fake-deployment') }
      let(:vm_model) { Bosh::Director::Models::Vm.make(deployment: deployment) }
      let(:stemcell) { Bosh::Director::Models::Stemcell.make(name: 'fake-stemcell', version: 'fake-stemcell-version') }

      context 'the agent on the existing VM has the requested static ip but no job instance assigned (due to deploy failure)' do
        before do
          allow(Bosh::Director::AgentClient).to receive(:with_defaults).and_return(agent_client)
          allow(agent_client).to receive(:apply)
          allow(agent_client).to receive(:drain).with('shutdown').and_return(0)
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
          let(:update_step) { Steps::UpdateStep.new(base_job, event_log, resource_pools, deployment_plan, multi_job_updater, cloud, blobstore) }

          let(:base_job) { Bosh::Director::Jobs::BaseJob.new }
          let(:multi_job_updater) { instance_double('Bosh::Director::DeploymentPlan::SerialMultiJobUpdater', run: nil) }
          let(:resource_pools) { ResourcePools.new(event_log, rp_updaters) }
          let(:rp_updaters) { deployment_plan.resource_pools.map { |resource_pool| Bosh::Director::ResourcePoolUpdater.new(resource_pool) } }
          let(:assembler) { Assembler.new(deployment_plan, nil, cloud, nil, logger, event_log) }
          let(:cloud_config) { nil }

          let(:deployment_plan) do
            planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(event_log, logger)
            planner_factory.planner(deployment_manifest, cloud_config, {})
          end
          let(:deployment_parser) { DeploymentSpecParser.new(event_log, logger) }
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

          before { allow(Bosh::Director::Config).to receive(:dns_enabled?).and_return(false) }

          before { allow(Bosh::Director::App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore) }
          let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

          before { allow_any_instance_of(Bosh::Director::JobRenderer).to receive(:render_job_instances) }

          it 'deletes the existing VM, and creates a new VM with the same IP' do
            expect(cloud).to receive(:delete_vm).with(vm_model.cid).ordered
            expect(cloud).to receive(:create_vm).with(anything, stemcell.cid, anything, { 'fake-network' => hash_including('ip' => '127.0.0.1') }, anything, anything).ordered

            update_step.perform
          end
        end
      end
    end
  end
end
