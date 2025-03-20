require 'spec_helper'

module Bosh::Director
  describe Addon::Filter do
    subject(:addon_filter) { Addon::Filter.parse(filter_spec, filter_type) }
    let(:deployment_name) { 'dep1' }
    let(:deployment_model) { FactoryBot.create(:models_deployment, name: deployment_name) }
    let(:deployment_plan) do
      planner_attributes = { name: deployment_name, properties: {} }
      cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config
      manifest = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      planner = DeploymentPlan::Planner.new(
        planner_attributes,
        manifest,
        YAML.dump(manifest),
        [FactoryBot.create(:models_config_cloud, content: YAML.dump(cloud_config))],
        SharedSupport::DeploymentManifestHelper.simple_runtime_config,
        deployment_model,
      )
      release1 = FactoryBot.create(:models_release, name: '1')
      release2 = FactoryBot.create(:models_release, name: '2')
      release_version1 = FactoryBot.create(:models_release_version, version: 'v1', release: release1)
      release_version2 = FactoryBot.create(:models_release_version, version: 'v2', release: release2)
      release_version1.add_template(FactoryBot.create(:models_template, name: 'job1', release: release1))
      release_version2.add_template(FactoryBot.create(:models_template, name: 'job2', release: release2))
      planner.add_release(DeploymentPlan::ReleaseVersion.parse(deployment_model, 'name' => '1', 'version' => 'v1'))
      planner.add_release(DeploymentPlan::ReleaseVersion.parse(deployment_model, 'name' => '2', 'version' => 'v2'))

      stemcell = DeploymentPlan::Stemcell.parse(manifest['stemcells'].first)
      planner.add_stemcell(stemcell)

      planner.cloud_planner = DeploymentPlan::CloudManifestParser.new(per_spec_logger).parse(cloud_config)
      planner.update = DeploymentPlan::UpdateConfig.new(manifest['update'])

      planner
    end

    before do
      deployment_model.add_variable_set(FactoryBot.create(:models_variable_set, deployment: deployment_model))
    end

    let(:instance_group1) do
      group1_spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'group1',
        jobs: [{ 'name' => 'job1', 'release' => '1' }],
      )
      DeploymentPlan::InstanceGroup.parse(deployment_plan, group1_spec, Config.event_log, per_spec_logger)
    end

    let(:instance_group2) do
      group2_spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'group2',
        jobs: [{ 'name' => 'job1', 'release' => '1' }, { 'name' => 'job2', 'release' => '2' }],
      )
      DeploymentPlan::InstanceGroup.parse(deployment_plan, group2_spec, Config.event_log, per_spec_logger)
    end

    shared_examples :addon_filters do
      context 'when ONLY deployments key is present in the filter spec' do
        let(:filter_spec) do
          { 'jobs' => [], 'deployments' => deployments }
        end

        context 'if deployment name is in filter section' do
          let(:deployments) { ['dep1'] }

          it 'should return true' do
            expect(subject.applies?('dep1', [], instance_group1)).to eq(true)
          end
        end

        context 'if deployment name is NOT in filter section' do
          let(:deployments) { ['dep42'] }

          it 'should return false' do
            expect(subject.applies?(deployment_name, [], instance_group1)).to eq(false)
          end
        end
      end

      context 'when ONLY jobs key is present in the filter spec' do
        let(:filter_spec) do
          {
            'jobs' => [{ 'name' => 'job1', 'release' => '1' }, { 'name' => 'job2', 'release' => '2' }],
            'deployments' => [],
          }
        end

        context 'when instance groups contains corresponding job and release' do
          it 'should return true' do
            expect(subject.applies?(deployment_name, [], instance_group1)).to eq(true)
          end
        end

        context 'when no instance groups contains corresponding job and release' do
          it 'returns false' do
            filter_spec['jobs'] = [{ 'name' => 'job1', 'release' => '2' }]
            expect(subject.applies?(deployment_name, [], instance_group1)).to eq(false)
          end
        end
      end

      context 'when BOTH deployments key and jobs key are present in the filter spec' do
        let(:filter_spec) do
          {
            'jobs' => [{ 'name' => 'job1', 'release' => '1' }, { 'name' => 'job2', 'release' => '2' }],
            'deployments' => ['dep1'],
          }
        end

        context 'when deployment name and job/releases corresponds to filter spec' do
          it 'should return instance groups that contain corresponding job and are in the corresponding deployments' do
            expect(subject.applies?(deployment_name, [], instance_group1)).to eq(true)
          end
        end
      end
    end

    describe '#applies?' do
      context 'include' do
        let(:filter_type) { :include }

        context 'when RuntimeManifest does not have an include section' do
          let(:filter_spec) { nil }

          it 'should return true' do
            expect(subject.applies?(deployment_name, [], instance_group1)).to eq(true)
          end
        end

        context 'when NEITHER deployments key nor jobs key are present' do
          let(:filter_spec) do
            { 'jobs' => [], 'deployments' => [] }
          end

          it 'returns true' do
            expect(subject.applies?(deployment_name, [], instance_group1)).to eq(true)
          end
        end

        it_behaves_like :addon_filters
      end

      context 'exclude' do
        let(:filter_type) { :exclude }

        context 'when RuntimeManifest does not have an include section' do
          let(:filter_spec) { nil }

          it 'should return true' do
            expect(subject.applies?(deployment_name, [], instance_group1)).to eq(false)
          end
        end

        context 'when NEITHER deployments key nor jobs key are present' do
          let(:filter_spec) do
            { 'jobs' => [], 'deployments' => [] }
          end

          it 'returns true' do
            expect(subject.applies?(deployment_name, [], instance_group1)).to eq(false)
          end
        end

        it_behaves_like :addon_filters
      end
    end
  end
end
