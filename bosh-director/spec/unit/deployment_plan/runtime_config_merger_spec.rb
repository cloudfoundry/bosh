require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::RuntimeConfigMerger do
    subject(:merger) { described_class.new(deployment) }
    let(:planner_options) { {} }
    let(:event_log) { Config.event_log }

    describe '#parse' do
      describe 'with deployment' do
        let(:cloud_config) { Models::CloudConfig.make }

        let(:deployment_model) do
          deployment_model = Models::Deployment.make
          deployment_model.cloud_config_id = cloud_config.id
          deployment_model.save
          deployment_model
        end

        let(:deployment_name) { 'dep1' }

        let(:manifest_hash) do
          manifest_hash = Bosh::Spec::Deployments.minimal_manifest
          manifest_hash['name'] = deployment_name
          manifest_hash
        end

        let(:deployment) do
          planner = DeploymentPlan::Planner.new({name: deployment_name, properties: {}}, manifest_hash, cloud_config, deployment_model, planner_options)
          planner.update = DeploymentPlan::UpdateConfig.new(manifest_hash['update'])
          planner
        end

        let(:release_version_model) { Bosh::Director::Models::ReleaseVersion.make(version: '0.2-dev', release: release_model) }
        let(:release_model) { Bosh::Director::Models::Release.make(name: 'dummy') }
        let(:job_parser) { DeploymentPlan::InstanceGroupSpecParser.new(deployment, event_log, logger)}

        before do
          release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy', release: release_model))

          release = DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'dummy', 'version' => '0.2-dev'})
          deployment.add_release(release)

          allow_any_instance_of(DeploymentPlan::Template).to receive(:bind_models).and_return(nil)
          allow_any_instance_of(DeploymentPlan::ReleaseVersion).to receive(:bind_model).and_return(nil)

          deployment.cloud_planner = DeploymentPlan::CloudManifestParser.new(@logger).parse(cloud_config.manifest,
                                                                                            DeploymentPlan::GlobalNetworkResolver.new(deployment, [], logger),
                                                                                            DeploymentPlan::IpProviderFactory.new(deployment.using_global_networking?, @logger))

          deployment.add_instance_group(job_parser.parse(Bosh::Spec::Deployments.dummy_job))
        end

        let(:release_specs) { [ {'name' => 'test_release_2', 'version' => '2'} ] }

        describe '#add_releases' do
          it 'adds ReleaseVersion models to deployment for releases listed in runtime manifest' do
            expect_any_instance_of(DeploymentPlan::ReleaseVersion).to receive(:bind_model).and_return(nil)

            subject.add_releases(release_specs)

            expect(deployment.release('test_release_2').version).to eq('2')
          end

          it 'raises RuntimeInvalidDeploymentRelease if deployment contains same release with different version than in runtime manifest' do
            deployment.add_release(DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'test_release_2', 'version' => '0.1'}))
            expect { subject.add_releases(release_specs) }.to raise_error(RuntimeInvalidDeploymentRelease)
          end

          it 'does not add a release that has already been added before' do
            subject.add_releases(release_specs)

            expect{subject.add_releases(release_specs)}.not_to raise_error
          end
        end
      end
    end
  end
end