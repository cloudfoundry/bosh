require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::RuntimeManifestParser do
    subject(:parser) { described_class.new(logger, deployment) }
    let(:planner_options) { {} }
    let(:event_log) { Config.event_log }

    describe '#parse' do
      let(:runtime_manifest) { Bosh::Spec::Deployments.simple_runtime_config }

      describe 'without deployment' do
        let(:deployment) { nil }

        it 'raises RuntimeAmbiguousReleaseSpec if manifest contains both release and releases' do
          runtime_manifest.merge!({'release' => {'name' => 'release2', 'version' => '0.1'}})
          expect { subject.parse(runtime_manifest) }.to raise_error(Bosh::Director::RuntimeAmbiguousReleaseSpec)
        end

        it "raises RuntimeInvalidReleaseVersion if a release uses version 'latest'" do
          runtime_manifest['releases'][0]['version'] = 'latest'
          expect { subject.parse(runtime_manifest) }.to raise_error(Bosh::Director::RuntimeInvalidReleaseVersion)
        end

        it "raises RuntimeInvalidReleaseVersion if a release uses relative version '.latest'" do
          runtime_manifest['releases'][0]['version'] = '3146.latest'
          expect { subject.parse(runtime_manifest) }.to raise_error(Bosh::Director::RuntimeInvalidReleaseVersion)
        end

        it "raises RuntimeReleaseNotListedInReleases if addon job's release is not listed in releases" do
          runtime_manifest = Bosh::Spec::Deployments.runtime_config_with_addon
          runtime_manifest['releases'][0]['name'] = 'weird_name'
          expect { subject.parse(runtime_manifest) }.to raise_error(RuntimeReleaseNotListedInReleases)
        end
      end

      describe 'with deployment' do
        let(:cloud_config) do
          cloud_config = Models::CloudConfig.make
          cloud_config.manifest = Bosh::Spec::Deployments.simple_cloud_config
          cloud_config.save
          cloud_config
        end

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

        before do
          release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy', release: release_model))

          job_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, event_log, logger)

          release = DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'dummy', 'version' => '0.2-dev'})
          deployment.add_release(release)

          allow_any_instance_of(DeploymentPlan::Template).to receive(:bind_models).and_return(nil)
          allow_any_instance_of(DeploymentPlan::ReleaseVersion).to receive(:bind_model).and_return(nil)

          deployment.cloud_planner = DeploymentPlan::CloudManifestParser.new(@logger).parse(cloud_config.manifest,
                                                                                            DeploymentPlan::GlobalNetworkResolver.new(deployment, [], logger),
                                                                                            DeploymentPlan::IpProviderFactory.new(deployment.using_global_networking?, @logger))

          deployment.add_instance_group(job_parser.parse(Bosh::Spec::Deployments.dummy_job))
        end

        it 'raises RuntimeInvalidDeploymentRelease if deployment contains same release with different version than in runtime manifest' do
          deployment.add_release(DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'test_release_2', 'version' => '0.1'}))
          expect { subject.parse(runtime_manifest) }.to raise_error(RuntimeInvalidDeploymentRelease)
        end

        it 'adds ReleaseVersion models to deployment for releases listed in runtime manifest' do
          allow_any_instance_of(DeploymentPlan::ReleaseVersion).to receive(:bind_model).and_return(true)
          subject.parse(runtime_manifest)
          expect(deployment.release('test_release_2').version).to eq('2')
        end

        it "does not throw an error when the consumes_json and provides_json are set to the string \"null\"" do
          release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy_with_properties', release: release_model, provides_json: 'null', consumes_json: 'null'))

          subject.parse(runtime_manifest)
        end

        context 'when runtime manifest does not have an include section' do
          let(:runtime_manifest) { Bosh::Spec::Deployments.runtime_config_with_addon }

          it 'appends addon jobs to deployment job templates and addon properties to deployment job properties' do
            subject.parse(runtime_manifest)

            expect(deployment.instance_group('dummy').templates.any? { |t| t.name == 'dummy_with_properties' }).to eq(true)
            expect(deployment.instance_group('dummy').all_properties['dummy_with_properties']['echo_value']).to eq('prop_value')
          end
        end
      end
    end
  end
end
