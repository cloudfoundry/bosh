require 'spec_helper'

module Bosh::Director
  module Addon
    describe Addon do
      subject(:addon) { Addon.new(addon_name, jobs, properties, includes, excludes) }
      let(:addon_name) { 'addon-name' }
      let(:jobs) {
        [
          {'name' => 'dummy_with_properties',
            'release' => 'dummy',
            'provides_links' => [],
            'consumes_links' => []},
          {'name' => 'dummy_with_package',
            'release' => 'dummy',
            'provides_links' => [],
            'consumes_links' => []}
        ]
      }
      let(:properties) { {'echo_value' => 'addon_prop_value'} }

      let(:cloud_config) { Models::CloudConfig.make }

      let(:teams) { Bosh::Director::Models::Team.transform_admin_team_scope_to_teams(['bosh.teams.team_1.admin', 'bosh.teams.team_3.admin']) }

      let(:deployment_model) do
        deployment_model = Models::Deployment.make
        deployment_model.cloud_config_id = cloud_config.id
        deployment_model.teams = teams
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
        planner = DeploymentPlan::Planner.new({name: deployment_name, properties: {}}, manifest_hash, cloud_config, {}, deployment_model)
        planner.update = DeploymentPlan::UpdateConfig.new(manifest_hash['update'])
        planner
      end

      let(:includes) { Filter.parse(include_spec, :include) }
      let(:excludes) { Filter.parse(exclude_spec, :exclude) }

      let(:exclude_spec) { nil }

      describe '#add_to_deployment' do
        let(:include_spec) { {'deployments' => [deployment_name]} }
        let(:instance_group) do
          instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
          jobs = [{'name' => 'dummy', 'release' => 'dummy'}]
          instance_group_parser.parse(Bosh::Spec::Deployments.simple_job(jobs: jobs), {})
        end
        let(:release_model) { Bosh::Director::Models::Release.make(name: 'dummy') }
        let(:release_version_model) { Bosh::Director::Models::ReleaseVersion.make(version: '0.2-dev', release: release_model) }

        before do
          release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy', release: release_model))
          release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy_with_properties', release: release_model))
          release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy_with_package', release: release_model))
          release = DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'dummy', 'version' => '0.2-dev'})
          deployment.add_release(release)
          deployment.cloud_planner = DeploymentPlan::CloudManifestParser.new(logger)
                                       .parse(Bosh::Spec::Deployments.simple_cloud_config,
                                         DeploymentPlan::GlobalNetworkResolver.new(deployment, [], logger),
                                         DeploymentPlan::IpProviderFactory.new(true, logger))

          deployment.add_instance_group(instance_group)
        end

        context 'when addon does not apply to the instance group' do
          let(:include_spec) { {'deployments' => ['no_findy']} }

          it 'does nothing' do
            expect(instance_group).to_not receive(:add_job)
            addon.add_to_deployment(deployment)
          end
        end

        context 'when addon does not apply to the deployment teams' do
          let(:include_spec) { {'teams' => ['team_2']} }

          it 'does nothing' do
            expect(instance_group).to_not receive(:add_job)
            addon.add_to_deployment(deployment)
          end
        end

        context 'when addon applies to instance group' do
          it 'adds addon to instance group' do
            addon.add_to_deployment(deployment)
            deployment_instance_group = deployment.instance_group(instance_group.name)
            expect(deployment_instance_group.jobs.map(&:name)).to eq(['dummy', 'dummy_with_properties', 'dummy_with_package'])
          end

          context 'none of the addon jobs have job level properties' do
            context 'when the addon has properties' do
              it 'adds addon properties to addon job' do
                addon.add_to_deployment(deployment)

                expect(instance_group.jobs[1].properties).to eq({'foobar' => properties})
                expect(instance_group.jobs[2].properties).to eq({'foobar' => properties})
              end
            end

            context 'when the addon has no addon level properties' do
              let(:properties) { {} }

              it 'adds empty properties to addon job so they do not get overwritten by instance group or manifest level properties' do
                added_jobs = []
                expect(instance_group).to(receive(:add_job)) { |job| added_jobs << job }.twice
                addon.add_to_deployment(deployment)

                expect(added_jobs[0].properties).to eq({'foobar' => {}})
                expect(added_jobs[1].properties).to eq({'foobar' => {}})
              end
            end
          end

          context 'when the addon jobs have job level properties' do
            let(:jobs) {
              [
                {'name' => 'dummy_with_properties',
                  'release' => 'dummy',
                  'provides_links' => [],
                  'consumes_links' => [],
                  'properties' => {'job' => 'properties'}
                }
              ]
            }

            it 'does not overwrite jobs properties with addon properties' do
              expect(instance_group).to(receive(:add_job)) { |added_job|
                expect(added_job.properties).to eq({'foobar' => {'job' => 'properties'}})
              }
              addon.add_to_deployment(deployment)
            end
          end
        end

        context 'when the addon has deployments in include and jobs in exclude' do
          let(:include_spec) { {'deployments' => [deployment_name]} }
          let(:exclude_spec) { {'jobs' => [{'name' => 'dummy', 'release' => 'dummy'}]} }

          it 'adds filtered jobs only' do
            expect(instance_group).not_to receive(:add_job)
            addon.add_to_deployment(deployment)
          end
        end
      end

      describe '#parse' do
        context 'when name, jobs, include, and properties' do
          let(:include_hash) { {'jobs' => [], 'properties' => []} }
          let(:addon_hash) { {
            'name' => 'addon-name',
            'jobs' => jobs,
            'properties' => properties,
            'include' => include_hash
          } }

          it 'returns addon' do
            expect(Filter).to receive(:parse).with(include_hash, :include, RUNTIME_LEVEL)
            expect(Filter).to receive(:parse).with(nil, :exclude, RUNTIME_LEVEL)
            addon = Addon.parse(addon_hash)
            expect(addon.name).to eq('addon-name')
            expect(addon.jobs.count).to eq(2)
            expect(addon.jobs.map { |job| job['name'] }).to eq(['dummy_with_properties', 'dummy_with_package'])
            expect(addon.properties).to eq(properties)
          end
        end

        context 'when jobs, properties and include are empty' do
          let(:addon_hash) { {'name' => 'addon-name'} }

          it 'returns addon' do
            addon = Addon.parse(addon_hash)
            expect(addon.name).to eq('addon-name')
            expect(addon.jobs.count).to eq(0)
            expect(addon.properties).to be_nil
          end
        end

        context 'when jobs, properties and include are empty' do
          let(:addon_hash) { {'name' => 'addon-name'} }

          it 'returns addon' do
            addon = Addon.parse(addon_hash)
            expect(addon.name).to eq('addon-name')
            expect(addon.jobs.count).to eq(0)
            expect(addon.properties).to be_nil
          end
        end

        context 'when name is empty' do
          let(:addon_hash) { {'jobs' => ['addon-name']} }

          it 'errors' do
            expect { Addon.parse(addon_hash) }.to raise_error ValidationMissingField,
              "Required property 'name' was not specified in object ({\"jobs\"=>[\"addon-name\"]})"
          end
        end
      end

      describe '#applies?' do
        context 'when the addon is applicable by deployment name' do
          let(:include_spec) { {'deployments' => [deployment_name]} }
          let(:deployment_instance_group) {
            instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
            instance_group_parser.parse(Bosh::Spec::Deployments.dummy_job)
          }

          it 'applies' do
            expect(addon.applies?(deployment_name, [], nil)).to eq(true)
          end
        end

        context 'when the addon is not applicable by deployment name' do
          let(:include_spec) { {'deployments' => [deployment_name]} }
          let(:deployment_instance_group) {
            instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
            instance_group_parser.parse(Bosh::Spec::Deployments.dummy_job)
          }

          it 'does not apply' do
            expect(addon.applies?('blarg', [], nil)).to eq(false)
          end
        end

        context 'when the addon is applicable by team' do
          let(:include_spec) { {'teams' => ['team_1']} }

          it 'applies' do
            expect(addon.applies?(deployment_name, ['team_1'], nil)).to eq(true)
          end
        end

        context 'when the addon is not applicable by team' do
          let(:include_spec) { {'teams' => ['team_5']} }

          it 'does not apply' do
            expect(addon.applies?(deployment_name, ['team_1'], nil)).to eq(false)
          end
        end

        context 'when the addon has empty include' do
          let(:include_spec) { {} }
          let(:deployment_instance_group) {
            instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
            instance_group_parser.parse(Bosh::Spec::Deployments.dummy_job)
          }

          it 'applies' do
            expect(addon.applies?(deployment_name, [], nil)).to eq(true)
          end
        end

        context 'when the addon has empty include and exclude' do
          let(:include_spec) { {} }
          let(:exclude_spec) { {} }
          let(:deployment_instance_group) {
            instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
            instance_group_parser.parse(Bosh::Spec::Deployments.dummy_job)
          }

          it 'applies' do
            expect(addon.applies?(deployment_name, [], nil)).to eq(true)
          end
        end

        context 'when the addon has include and exclude' do
          let(:include_spec) { {'deployments' => [deployment_name]} }
          context 'when they are the same' do
            let(:exclude_spec) { {'deployments' => [deployment_name]} }
            let(:deployment_instance_group) {
              instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
              instance_group_parser.parse(Bosh::Spec::Deployments.dummy_job)
            }

            it 'does not apply' do
              expect(addon.applies?(deployment_name, [], nil)).to eq(false)
            end
          end

          context 'when include is for deployment and exlude is for job' do
            let(:exclude_spec) { {'jobs' => [{'name' => 'dummy', 'release' => 'dummy'}]}  }
            let(:instance_group_parser) {DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)}
            let(:release_model) { Bosh::Director::Models::Release.make(name: 'dummy') }
            let(:release_version_model) { Bosh::Director::Models::ReleaseVersion.make(version: '0.2-dev', release: release_model) }

            before do
              release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy', release: release_model))
              release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy_with_properties', release: release_model))

              release = DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'dummy', 'version' => '0.2-dev'})
              deployment.add_release(release)
              deployment.cloud_planner = DeploymentPlan::CloudManifestParser.new(logger)
                .parse(Bosh::Spec::Deployments.simple_cloud_config,
                       DeploymentPlan::GlobalNetworkResolver.new(deployment, [], logger),
                       DeploymentPlan::IpProviderFactory.new(true, logger))
              instance_group1 = instance_group_parser.parse(Bosh::Spec::Deployments.simple_job(jobs: [{'name' => 'dummy', 'release' => 'dummy'}]), {})
              deployment.add_instance_group(instance_group1)
              instance_group2 = instance_group_parser.parse(Bosh::Spec::Deployments.simple_job(jobs: [{'name' => 'dummy_with_properties', 'release' => 'dummy'}], name: 'foobar1'), {})
              deployment.add_instance_group(instance_group2)
            end

            it 'exludes specified job only' do
              expect(addon.applies?(deployment_name, [], deployment.instance_group('foobar'))).to eq(false)
              expect(addon.applies?(deployment_name, [], deployment.instance_group('foobar1'))).to eq(true)
            end
          end
        end
      end
    end
  end
end
