require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::JobMigrator do
    subject(:job_migrator) { described_class.new(deployment_plan, logger) }
    let(:event_log) { Config.event_log }

    let(:etcd_job) do
      DeploymentPlan::Job.parse(deployment_plan, job_spec, event_log, logger)
    end

    let(:etcd_job_spec) do
      Bosh::Spec::Deployments.simple_job(name: 'etcd', instances: 4)
    end

    let(:deployment_manifest) do
      manifest = Bosh::Spec::Deployments.simple_manifest
      manifest['jobs'] = [etcd_job_spec]
      manifest
    end

    let(:job_spec) do
      deployment_manifest['jobs'].first
    end

    let(:cloud_config_manifest) do
      Bosh::Spec::Deployments.simple_cloud_config
    end

    let(:deployment_model) do
      cloud_config = Models::CloudConfig.make(manifest: cloud_config_manifest)
      Models::Deployment.make(
        name: deployment_manifest['name'],
        manifest: YAML.dump(deployment_manifest),
        cloud_config: cloud_config,
      )
    end

    let(:deployment_plan) do
      planner_factory = DeploymentPlan::PlannerFactory.create(event_log, logger)
      plan = planner_factory.create_from_model(deployment_model)
      plan.bind_models
      plan
    end

    before do
      fake_locks
      prepare_deploy(deployment_manifest, cloud_config_manifest)
    end

    describe 'find_existing_instances' do
      context 'when job needs to be migrated from' do
        let(:etcd_job_spec) do
          job = Bosh::Spec::Deployments.simple_job(name: 'etcd', instances: 4)
          job['migrated_from'] = [
            {'name' => 'etcd_z1', 'az' => 'z1'},
            {'name' => 'etcd_z2', 'az' => 'z2'},
          ]
          job
        end

        context 'when migrated_from job exists in previous deployment' do
          context 'when job does not have existing instances' do
            let!(:migrated_job_instances) do
              instances = []
              instances << Models::Instance.make(job: 'etcd_z1', index: 0, deployment: deployment_model, vm: nil)
              instances << Models::Instance.make(job: 'etcd_z1', index: 1, deployment: deployment_model, vm: nil)
              instances << Models::Instance.make(job: 'etcd_z1', index: 2, deployment: deployment_model, vm: nil)
              instances << Models::Instance.make(job: 'etcd_z2', index: 0, deployment: deployment_model, vm: nil)
              instances << Models::Instance.make(job: 'etcd_z2', index: 1, deployment: deployment_model, vm: nil)
              instances
            end

            it 'returns existing instance of migrating jobs' do
              migrated_instances = job_migrator.find_existing_instances_with_azs(etcd_job)
              expect(migrated_instances).to contain_exactly(
                be_a_migrated_instance(migrated_job_instances[0], 'z1'),
                be_a_migrated_instance(migrated_job_instances[1], 'z1'),
                be_a_migrated_instance(migrated_job_instances[2], 'z1'),
                be_a_migrated_instance(migrated_job_instances[3], 'z2'),
                be_a_migrated_instance(migrated_job_instances[4], 'z2'),
              )
            end
          end

          context 'when job already has existing instances' do
            let!(:existing_job_instances) do
              job_instances = []
              job_instances << Models::Instance.make(job: 'etcd', deployment: deployment_model, vm: nil, index: 0, bootstrap: true)
              job_instances << Models::Instance.make(job: 'etcd', deployment: deployment_model, vm: nil, index: 1)
              job_instances
            end

            let!(:migrated_job_instances) do
              instances = []
              instances << Models::Instance.make(job: 'etcd_z1', index: 0, deployment: deployment_model, vm: nil)
              instances << Models::Instance.make(job: 'etcd_z1', index: 1, deployment: deployment_model, vm: nil)
              instances << Models::Instance.make(job: 'etcd_z1', index: 2, deployment: deployment_model, vm: nil)
              instances << Models::Instance.make(job: 'etcd_z2', index: 0, deployment: deployment_model, vm: nil)
              instances << Models::Instance.make(job: 'etcd_z2', index: 1, deployment: deployment_model, vm: nil)
              instances << Models::Instance.make(job: 'etcd_z2', index: 2, deployment: deployment_model, vm: nil)

              instances
            end

            it 'return all existing job instances plus extra instances from etcd_z1 and etcd_z2' do
              migrated_instances = job_migrator.find_existing_instances_with_azs(etcd_job)
              expect(migrated_instances).to contain_exactly(
                  be_a_migrated_instance(existing_job_instances[0], nil),
                  be_a_migrated_instance(existing_job_instances[1], nil),
                  be_a_migrated_instance(migrated_job_instances[0], 'z1'),
                  be_a_migrated_instance(migrated_job_instances[1], 'z1'),
                  be_a_migrated_instance(migrated_job_instances[2], 'z1'),
                  be_a_migrated_instance(migrated_job_instances[3], 'z2'),
                  be_a_migrated_instance(migrated_job_instances[4], 'z2'),
                  be_a_migrated_instance(migrated_job_instances[5], 'z2'),
                )
            end
          end

          context 'when job was already migrated from the same jobs' do
            xit 'returns existing instances'
          end

          context 'when job was already migrated from different jobs' do
            xit 'returns existing instances'
          end
        end

        context 'when migrated_from job is still referenced in new deployment' do
          let(:deployment_manifest) do
            manifest = Bosh::Spec::Deployments.simple_manifest
            manifest['jobs'] = [
              etcd_job_spec,
              Bosh::Spec::Deployments.simple_job(name: 'etcd_z1'),
              Bosh::Spec::Deployments.simple_job(name: 'etcd_z2'),
            ]
            manifest
          end

          it 'raises an error' do
            expect {
              job_migrator.find_existing_instances(etcd_job)
            }.to raise_error(
                DeploymentInvalidMigratedFromJob,
                "Failed to migrate job 'etcd_z1' to 'etcd', deployment still contains it"
              )
          end
        end

        context 'when two jobs migrate from the same job' do
          let(:deployment_manifest) do
            manifest = Bosh::Spec::Deployments.simple_manifest
            another_job_spec = Bosh::Spec::Deployments.simple_job(name: 'another')
            another_job_spec['migrated_from'] = etcd_job_spec['migrated_from']
            manifest['jobs'] = [
              etcd_job_spec,
              another_job_spec
            ]
            manifest
          end

          it 'raises an error' do
            expect {
              job_migrator.find_existing_instances(etcd_job)
            }.to raise_error(
                DeploymentInvalidMigratedFromJob,
                "Failed to migrate job 'etcd_z1' to 'etcd', can only be used in one job to migrate"
              )
          end
        end
      end

      context 'when job does not need to be migrated' do
        let!(:existing_job_instances) do
          job_instances = []
          job_instances << Models::Instance.make(job: 'etcd', deployment: deployment_model, vm: nil)
          job_instances << Models::Instance.make(job: 'etcd', deployment: deployment_model, vm: nil)
          job_instances
        end

        it 'returns the list of existing job instances' do
          migrated_instances = job_migrator.find_existing_instances_with_azs(etcd_job)
          expect(migrated_instances).to contain_exactly(
              be_a_migrated_instance(existing_job_instances[0], nil),
              be_a_migrated_instance(existing_job_instances[1], nil)
            )
        end
      end
    end
  end
end

RSpec::Matchers.define :be_a_migrated_instance do |model, az|
  match do |actual|
    actual.model == model && actual.az == az
  end
end

