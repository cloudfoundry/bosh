require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::RuntimeManifestParser do
    subject(:parser) { described_class.new(logger, deployment) }
    let(:planner_options) { {} }
    let(:event_log) { Config.event_log }

    describe '#parse' do
      let(:runtime_manifest) { Bosh::Spec::Deployments.simple_runtime_config }

      describe "without deployment" do
        let(:deployment) { nil }

        it "raises RuntimeAmbiguousReleaseSpec if manifest contains both release and releases" do
          runtime_manifest.merge!({'release' => {'name' => 'release2', 'version' => '0.1'}})
          expect {subject.parse(runtime_manifest)}.to raise_error(Bosh::Director::RuntimeAmbiguousReleaseSpec)
        end

        it "raises RuntimeInvalidReleaseVersion if a release uses version 'latest'" do
          runtime_manifest['releases'][0]['version'] = 'latest'
          expect {subject.parse(runtime_manifest)}.to raise_error(Bosh::Director::RuntimeInvalidReleaseVersion)
        end

        it "raises RuntimeReleaseNotListedInReleases if addon job's release is not listed in releases" do
          runtime_manifest = Bosh::Spec::Deployments.runtime_config_with_addon
          runtime_manifest['releases'][0]['name'] = 'weird_name'
          expect {subject.parse(runtime_manifest)}.to raise_error(RuntimeReleaseNotListedInReleases)
        end
      end

      describe "with deployment" do
        let(:deployment_model) do
          deployment_model = Models::Deployment.make
          deployment_model.cloud_config_id = 1
          deployment_model.save
          deployment_model
        end

        let(:manifest_hash) do
          {
            'name' => 'deployment-name',
            'releases' => [],
            'networks' => [{ 'name' => 'network-name' }],
            'compilation' => {},
            'update' => {},
            'resource_pools' => []
          }
        end

        let(:cloud_config) do
          cloud_config = Models::CloudConfig.make
          cloud_config.manifest = Bosh::Spec::Deployments.simple_cloud_config
          cloud_config.save
          cloud_config
        end

        let(:planner_attributes) {
          {
            name: manifest_hash['name'],
            properties: manifest_hash['properties'] || {}
          }
        }

        let(:deployment) { DeploymentPlan::Planner.new(planner_attributes, manifest_hash, cloud_config, deployment_model, planner_options) }

        it "raises RuntimeInvalidDeploymentRelease if deployment contains same release with different version than in runtime manifest" do
          deployment.add_release(DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'test_release_2', 'version' => '0.1'}))
          expect {subject.parse(runtime_manifest)}.to raise_error(RuntimeInvalidDeploymentRelease)
        end

        it "adds ReleaseVersion models to deployment for releases listed in runtime manifest" do
          allow_any_instance_of(DeploymentPlan::ReleaseVersion).to receive(:bind_model).and_return(true)
          subject.parse(runtime_manifest)
          expect(deployment.release('test_release_2').version).to eq("2")
        end

        it "does not throw an error when the consumes_json and provides_json are set to the string \"null\"" do
          release_model = Bosh::Director::Models::Release.make(name: 'dummy2')
          release_version_model = Bosh::Director::Models::ReleaseVersion.make(version: '0.2-dev', release: release_model)
          release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy', release: release_model))
          release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy_with_properties', release: release_model, provides_json: "null", consumes_json: "null"))

          runtime_manifest = Bosh::Spec::Deployments.runtime_config_with_addon
          job_parser = DeploymentPlan::JobSpecParser.new(deployment, event_log, logger)

          release = DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'dummy2', 'version' => '0.2-dev'})
          deployment.add_release(release)

          deployment.cloud_planner = DeploymentPlan::CloudManifestParser.new(@logger).parse(cloud_config.manifest,
            DeploymentPlan::GlobalNetworkResolver.new(deployment),
            DeploymentPlan::IpProviderFactory.new(deployment.using_global_networking?, @logger))

          deployment.add_job(job_parser.parse({
                                                  'name' => 'dummy',
                                                  'templates' => [{'name'=> 'dummy', 'release' => 'dummy2'}],
                                                  'resource_pool' => 'a',
                                                  'networks' => [{'name' => 'a'}],
                                                  'instances' => 1,
                                                  'update' => {
                                                      'canaries'          => 2,
                                                      'canary_watch_time' => 4000,
                                                      'max_in_flight'     => 1,
                                                      'update_watch_time' => 20
                                                  }
                                              }))

          subject.parse(runtime_manifest)
        end

        it "appends addon jobs to deployment job templates and addon properties to deployment job properties" do
          release_model = Bosh::Director::Models::Release.make(name: 'dummy')
          release_version_model = Bosh::Director::Models::ReleaseVersion.make(version: '0.2-dev', release: release_model)
          release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy', release: release_model))

          runtime_manifest = Bosh::Spec::Deployments.runtime_config_with_addon
          job_parser = DeploymentPlan::JobSpecParser.new(deployment, event_log, logger)

          release = DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'dummy', 'version' => '0.2-dev'})
          deployment.add_release(release)

          allow_any_instance_of(DeploymentPlan::Template).to receive(:bind_models).and_return(nil)
          allow_any_instance_of(DeploymentPlan::ReleaseVersion).to receive(:bind_model).and_return(nil)

          deployment.cloud_planner = DeploymentPlan::CloudManifestParser.new(@logger).parse(cloud_config.manifest,
            DeploymentPlan::GlobalNetworkResolver.new(deployment),
            DeploymentPlan::IpProviderFactory.new(deployment.using_global_networking?, @logger))

          deployment.add_job(job_parser.parse({
            'name' => 'dummy',
            'templates' => [{'name'=> 'dummy', 'release' => 'dummy'}],
            'resource_pool' => 'a',
            'networks' => [{'name' => 'a'}],
            'instances' => 1,
            'update' => {
              'canaries'          => 2,
              'canary_watch_time' => 4000,
              'max_in_flight'     => 1,
              'update_watch_time' => 20
            }
          }))

          subject.parse(runtime_manifest)

          expect(deployment.job('dummy').templates.any? {|t| t.name == 'dummy_with_properties'}).to eq(true)
          expect(deployment.job('dummy').all_properties['dummy_with_properties']['echo_value']).to eq('prop_value')
        end
      end
    end
  end
end
