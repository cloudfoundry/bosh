require 'spec_helper'

module Bosh::Director
  describe RuntimeConfig::AddonInclude do

    subject(:addon_include) { RuntimeConfig::AddonInclude.parse(include_spec) }
    let(:deployment_name) { 'dep1' }
    let(:deployment_model) { Models::Deployment.make(name: deployment_name) }
    let(:deployment_plan) do
      planner_attributes = {name: deployment_name, properties: {}}
      cloud_config = Bosh::Spec::Deployments.simple_cloud_config
      manifest = Bosh::Spec::Deployments.simple_manifest
      planner = DeploymentPlan::Planner.new(planner_attributes, manifest, cloud_config, Bosh::Spec::Deployments.simple_runtime_config, deployment_model)

      release1 = Models::Release.make(name: '1')
      release2 = Models::Release.make(name: '2')
      release_version1 = Models::ReleaseVersion.make(version: 'v1', release: release1)
      release_version2 = Models::ReleaseVersion.make(version: 'v2', release: release2)
      release_version1.add_template(Models::Template.make(name: 'job1', release: release1))
      release_version2.add_template(Models::Template.make(name: 'job2', release: release2))
      planner.add_release(DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => '1', 'version' => 'v1'}))
      planner.add_release(DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => '2', 'version' => 'v2'}))

      planner.cloud_planner = DeploymentPlan::CloudManifestParser.new(logger).parse(cloud_config,
        DeploymentPlan::GlobalNetworkResolver.new(planner, [], logger),
        DeploymentPlan::IpProviderFactory.new(true, logger))
      planner.update = DeploymentPlan::UpdateConfig.new(manifest['update'])

      planner
    end

    let(:instance_group1) do
      group1_spec = Bosh::Spec::Deployments.simple_instance_group(name: 'group1', jobs: [{'name' => 'job1', 'release' => '1'}])
      DeploymentPlan::InstanceGroup.parse(deployment_plan, group1_spec, Config.event_log, logger)
    end

    let(:instance_group2) do
      group2_spec = Bosh::Spec::Deployments.simple_instance_group(name: 'group2', jobs: [{'name' => 'job1', 'release' => '1'}, {'name' => 'job2', 'release' => '2'}])
      DeploymentPlan::InstanceGroup.parse(deployment_plan, group2_spec, Config.event_log, logger)
    end

    describe '#applies?' do
      context 'when RuntimeManifest does not have an include section' do
        let(:include_spec) { nil }

        it 'should return true' do
          expect(subject.applies?(deployment_name, instance_group1)).to eq(true)
        end
      end

      context 'when ONLY deployments key is present in the include spec' do
        let(:include_spec) { {'jobs' => [], 'deployments' => deployments} }

        context 'if deployment name is in include section' do
          let(:deployments) { ['dep1'] }

          it 'should return true' do
            expect(subject.applies?('dep1', instance_group1)).to eq(true)
          end
        end

        context 'if deployment name is NOT in include section' do
          let(:deployments) { ['dep42'] }

          it 'should return false' do
            expect(subject.applies?(deployment_name, instance_group1)).to eq(false)
          end
        end
      end

      context 'when ONLY jobs key is present in the include spec' do
        let(:include_spec) do
          {
            'jobs' => [{'name' => 'job1', 'release' => '1'}, {'name' => 'job2', 'release' => '2'}],
            'deployments' => []
          }
        end

        context 'when instance groups contains corresponding job and release' do
          it 'should return true' do
            expect(subject.applies?(deployment_name, instance_group1)).to eq(true)
          end
        end

        context 'when no instance groups contains corresponding job and release' do
          it 'returns false' do
            include_spec['jobs'] = [{'name' => 'job1', 'release' => '2'}]
            expect(subject.applies?(deployment_name, instance_group1)).to eq(false)
          end
        end
      end

      context 'when BOTH deployments key and jobs key are present in the include spec' do
        let(:include_spec) do
          {
            'jobs' => [{'name' => 'job1', 'release' => '1'}, {'name' => 'job2', 'release' => '2'}],
            'deployments' => ['dep1']
          }
        end

        context 'when deployment name and job/releases corresponds to include spec' do
          it 'should return instance groups that contain corresponding job and are in the corresponding deployments' do
            expect(subject.applies?(deployment_name, instance_group1)).to eq(true)
          end
        end
      end

      context 'when NEITHER deployments key nor jobs key are present' do
        let(:include_spec) { {'jobs' => [], 'deployments' => []} }

        it 'returns true' do
          expect(subject.applies?(deployment_name, instance_group1)).to eq(true)
        end
      end
    end
  end
end
