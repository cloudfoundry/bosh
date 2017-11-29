require 'spec_helper'

module Bosh::Director
  module DeploymentPlan::Stages
    describe PersistDeploymentStage do
      subject { described_class.new(deployment_planner) }
      let(:deployment_model) { Models::Deployment.make }
      let(:deployment_planner) { instance_double(DeploymentPlan::Planner) }

      let(:minimal_manifest) do
        {
          'name' => 'minimal',

          'releases' => [{
            'name' => 'appcloud',
            'version' => '0.1' # It's our dummy valid release from spec/assets/valid_release.tgz
          }],

          'networks' => [{
            'name' => 'a',
            'subnets' => [],
          }],

          'compilation' => {
            'workers' => 1,
            'network' => 'a',
            'cloud_properties' => {},
          },

          'resource_pools' => [],

          'update' => {
            'canaries' => 2,
            'canary_watch_time' => 4000,
            'max_in_flight' => 1,
            'update_watch_time' => 20
          }
        }
      end

      let(:raw_manifest_text) do
      %Q(---
        name: minimal
        releases:
          - name: appcloud
            version: "0.1")
      end
      let(:cloud_config) { Models::Config.make(:cloud)}
      let(:runtime_configs) { [Models::Config.make(:runtime), Models::Config.make(:runtime), Models::Config.make(:runtime), Models::Config.make(:runtime)] }
      let(:link_spec) {
        {
          'instance_group' => {
            'job_1' => {
              'link_name' => {
                'db' => {
                  'properties' => {
                    'username' => 'name',
                    'password' => 'password'
                  }
                }
              }
            }
          }
        }
      }

      before do
        allow(deployment_planner).to receive(:uninterpolated_manifest_hash).and_return(minimal_manifest)
        allow(deployment_planner).to receive(:raw_manifest_text).and_return(raw_manifest_text)
        Bosh::Director::App.new(Bosh::Director::Config.load_hash(SpecHelper.spec_get_director_config))
        allow(deployment_planner).to receive(:model).and_return(deployment_model)
      end

      describe '#perform' do
        context 'given prior deployment with old release versions', truncation: true, :if => ENV.fetch('DB', 'sqlite') != 'sqlite' do
          let(:stale_release_version) do
            release = Bosh::Director::Models::Release.create(name: 'stale')
            Bosh::Director::Models::ReleaseVersion.create(release: release, version: '123')
          end
          let(:another_stale_release_version) do
            release = Bosh::Director::Models::Release.create(name: 'another_stale')
            Bosh::Director::Models::ReleaseVersion.create(release: release, version: '123')
          end
          let!(:same_release_version) do
            release = Bosh::Director::Models::Release.create(name: 'same')
            Bosh::Director::Models::ReleaseVersion.create(release: release, version: '123')
          end
          let!(:new_release_version) do
            release = Bosh::Director::Models::Release.create(name: 'new')
            Bosh::Director::Models::ReleaseVersion.create(release: release, version: '123')
          end

          before do
            deployment_model.add_release_version stale_release_version
            deployment_model.add_release_version another_stale_release_version
            deployment_model.add_release_version same_release_version

            deployment_plan_release_version_same_release = DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'same', 'version' => '123'})
            deployment_plan_release_version_new_release = DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'new', 'version' => '123'})
            deployment_plan_release_version_same_release.bind_model
            deployment_plan_release_version_new_release.bind_model

            allow(deployment_planner).to receive(:releases).and_return([
              deployment_plan_release_version_same_release,
              deployment_plan_release_version_new_release,
            ])
            allow(deployment_planner).to receive(:cloud_configs).and_return([cloud_config])
            allow(deployment_planner).to receive(:runtime_configs).and_return(runtime_configs)
            allow(deployment_planner).to receive(:link_spec).and_return(link_spec)
          end

          it 'updates the release version on the deployment to be the ones from the provided manifest', ENV do
            expect(deployment_model.release_versions).to include(stale_release_version)
            subject.perform
            expect(deployment_model.release_versions).to_not include(stale_release_version)
            expect(deployment_model.release_versions).to include(same_release_version)
            expect(deployment_model.release_versions).to include(new_release_version)
          end

          it 'saves original manifest' do
            subject.perform
            reloaded_model = deployment_model.reload
            expect(reloaded_model.manifest).to eq(YAML.dump(minimal_manifest))
          end

          it 'saves original raw manifest' do
            subject.perform
            reloaded_model = deployment_model.reload
            expect(reloaded_model.manifest_text).to eq(raw_manifest_text)
          end

          it 'saves cloud config' do
            subject.perform
            reloaded_model = deployment_model.reload
            expect(reloaded_model.cloud_configs).to eq([cloud_config])
          end

          it 'saves runtime config' do
            subject.perform
            reloaded_model = deployment_model.reload
            expect(reloaded_model.runtime_configs).to eq(runtime_configs)
          end

          it 'saves link_spec' do
            subject.perform
            reloaded_model = deployment_model.reload
            expect(reloaded_model.link_spec).to eq(link_spec)
          end
        end
      end
    end
  end
end
