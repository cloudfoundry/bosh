require 'spec_helper'

module Bosh::Director
  module DeploymentPlan::Steps
    describe SetupStep do
      describe 'deployment prepare & update', truncation: true, :if => ENV.fetch('DB', 'sqlite') != 'sqlite' do
        before do
          release = Models::Release.make(name: 'fake-release')

          release_version = Models::ReleaseVersion.make(version: '1.0.0')
          release.add_version(release_version)

          template = Models::Template.make(name: 'fake-template')
          release_version.add_template(template)
        end

        let(:deployment) { Models::Deployment.make(name: 'fake-deployment') }
        let!(:stemcell) { Models::Stemcell.make({'name' => 'fake-stemcell', 'version' => 'fake-stemcell-version'}) }

        let(:setup_step) { SetupStep.new(base_job, deployment_plan, vm_creator) }

        let(:base_job) { Jobs::BaseJob.new }
        let(:cloud_config) { nil }
        let(:runtime_config) { nil }

        let(:vm_creator) { instance_double('Bosh::Director::VmCreator') }

        let(:deployment_plan) do
          planner_factory = DeploymentPlan::PlannerFactory.create(logger)
          manifest = Manifest.new(deployment_manifest, deployment_manifest, nil, nil, nil)
          planner_factory.create_from_manifest(manifest, cloud_config, runtime_config, {})
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

        context 'when the director database contains no instances' do
          it 'creates vms for instance groups missing vms and checkpoints task' do
            expect(vm_creator).to receive(:create_for_instance_plans).with(
              deployment_plan.instance_plans_with_missing_vms,
              deployment_plan.ip_provider,
              deployment_plan.tags
            )

            expect(base_job).to receive(:task_checkpoint)
            setup_step.perform
          end
        end
      end
    end
  end
end
