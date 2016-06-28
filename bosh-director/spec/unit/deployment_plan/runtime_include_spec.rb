require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::RuntimeInclude do

    subject(:runtime_include) { described_class.new(include_spec) }
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

    let(:instance_groups) do
      group1_spec = Bosh::Spec::Deployments.simple_instance_group(name: 'group1', jobs: [{'name' => 'job1', 'release' => '1'}])
      group2_spec = Bosh::Spec::Deployments.simple_instance_group(name: 'group2', jobs: [{'name' => 'job1', 'release' => '1'}, {'name' => 'job2', 'release' => '2'}])
      [DeploymentPlan::InstanceGroup.parse(deployment_plan, group1_spec, Config.event_log, logger),
       DeploymentPlan::InstanceGroup.parse(deployment_plan, group2_spec, Config.event_log, logger)]
    end

    describe '#find_matching_instance_group' do
      context 'when RuntimeManifest does not have an include section' do
        let(:include_spec) { nil }

        it 'should return all instance groups' do
          expect(subject.find_matching_instance_group('addon1', instance_groups, deployment_name).map(&:name)).to eq(['group1', 'group2'])
        end
      end

      context 'when ONLY deployments key is present in the include spec' do
        let(:include_spec) { {'addon1' => {'jobs' => [], 'deployments' => deployments},
                              'addon2' => {'jobs' => [], 'deployments' => []}} }

        context 'if deployment name is in include section' do
          let(:deployments) { ['dep1'] }

          it 'should return all instance groups in the deployment' do
            expect(subject.find_matching_instance_group('addon1', instance_groups, deployment_name).map(&:name)).to eq(['group1', 'group2'])
          end
        end
        context 'if deployment name is NOT in include section' do
          let(:deployments) { ['dep42'] }

          it 'should return empty array' do
            expect(subject.find_matching_instance_group('addon1', instance_groups, deployment_name).map(&:name)).to eq([])
          end
        end
      end

      context 'when ONLY jobs key is present in the include spec' do
        let(:include_spec) { {'addon1' => {'jobs' => [{'name' => 'job1', 'release' => '1'}, {'name' => 'job2', 'release' => '2'}], 'deployments' => []},
                              'addon2' => {'jobs' => [{'name' => 'job2', 'release' => '2'}], 'deployments' => []}} }

        it 'should return all instance groups that contain corresponding job and release' do
          expect(subject.find_matching_instance_group('addon1', instance_groups, deployment_name).map(&:name)).to eq(['group1', 'group2'])
          expect(subject.find_matching_instance_group('addon2', instance_groups, deployment_name).map(&:name)).to eq(['group2'])
        end

        it 'does not return instance groups that contain corresponding job on a different release' do
          include_spec['addon2']['jobs'] = [{'name' => 'job1', 'release' => '2'}]
          expect(subject.find_matching_instance_group('addon2', instance_groups, deployment_name).map(&:name)).to eq([])
        end
      end

      context 'when BOTH deployments key and jobs key are present in the include spec' do
        let(:include_spec) { {'addon1' => {'jobs' => [{'name' => 'job1', 'release' => '1'}, {'name' => 'job2', 'release' => '2'}], 'deployments' => ['dep1']},
                              'addon2' => {'jobs' => [{'name' => 'job2', 'release' => '2'}], 'deployments' => ['dep1']}} }

        it 'should return instance groups that contain corresponding job and are in the corresponding deployments' do
          expect(subject.find_matching_instance_group('addon1', instance_groups, deployment_name).map(&:name)).to eq(['group1', 'group2'])
          expect(subject.find_matching_instance_group('addon2', instance_groups, deployment_name).map(&:name)).to eq(['group2'])
        end
      end

      context 'when NEITHER deployments key nor jobs key are present' do
        let(:include_spec) { {'addon1' => {'jobs' => [], 'deployments' => []}} }

        it 'returns all instance_groups' do
          expect(subject.find_matching_instance_group('addon1', instance_groups, deployment_name).map(&:name)).to eq(['group1', 'group2'])
        end
      end
    end
  end
end


