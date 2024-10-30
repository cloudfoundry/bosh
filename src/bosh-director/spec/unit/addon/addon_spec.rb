require 'spec_helper'

module Bosh::Director
  module Addon
    describe Addon, truncation: true do
      subject(:addon) { Addon.new(addon_name, jobs, includes, excludes, addon_properties) }
      let(:addon_name) { 'addon-name' }

      let(:jobs) do
        [
          {
            'name' => 'dummy_with_properties',
            'release' => 'dummy',
            'provides_links' => [],
            'consumes_links' => [],
            'properties' => properties,
          },
          {
            'name' => 'dummy_with_package',
            'release' => 'dummy',
            'provides_links' => [],
            'consumes_links' => [],
          },
        ]
      end

      let(:addon_properties) { {} }

      let(:properties) do
        { 'echo_value' => 'addon_prop_value' }
      end

      let(:cloud_configs) { [FactoryBot.create(:models_config_cloud, :with_manifest)] }

      let(:teams) do
        Bosh::Director::Models::Team.transform_admin_team_scope_to_teams(
          %w[bosh.teams.team_1.admin bosh.teams.team_3.admin],
        )
      end

      let(:deployment_model) do
        deployment_model = FactoryBot.create(:models_deployment)
        deployment_model.teams = teams
        deployment_model.cloud_configs = cloud_configs
        deployment_model.save
        deployment_model
      end

      let!(:variable_set) { FactoryBot.create(:models_variable_set, deployment: deployment_model) }

      let(:deployment_name) { 'dep1' }
      let(:instance_group) do
        DeploymentPlan::InstanceGroup.parse(
          deployment,
          instance_group_spec,
          Config.event_log,
          logger,
        )
      end

      let(:instance_group_spec) do
        jobs = [{ 'name' => 'dummy', 'release' => 'dummy' }]
        SharedSupport::DeploymentManifestHelper.simple_instance_group(jobs: jobs, azs: ['z1'])
      end

      let(:manifest_hash) do
        manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
        manifest_hash['name'] = deployment_name
        manifest_hash
      end

      let(:deployment) do
        planner = DeploymentPlan::Planner.new(
          deployment_name,
          manifest_hash,
          YAML.dump(manifest_hash),
          cloud_configs,
          {},
          deployment_model,
        )
        planner.update = DeploymentPlan::UpdateConfig.new(manifest_hash['update'])
        planner
      end

      let(:includes) { Filter.parse(include_spec, :include) }
      let(:excludes) { Filter.parse(exclude_spec, :exclude) }

      let(:exclude_spec) { nil }
      let(:include_spec) { nil }

      describe '#add_to_deployment' do
        let(:include_spec) do
          { 'deployments' => [deployment_name] }
        end

        let(:release_model) { FactoryBot.create(:models_release, name: 'dummy') }
        let(:release_version_model) { FactoryBot.create(:models_release_version, version: '0.2-dev', release: release_model) }

        let(:dummy_template_spec) do
          {
            'provides' => [
              {
                'name' => 'provided_links_101',
                'type' => 'type_101',
              },
            ],
            'consumes' => [
              {
                'name' => 'consumed_links_102',
                'type' => 'type_102',
              },
            ],
          }
        end

        let(:dummy_with_properties_template_spec) do
          {
            'provides' => [
              {
                'name' => 'provided_links_1',
                'type' => 'type_1',
              },
              {
                'name' => 'provided_links_2',
                'type' => 'type_2',
              },
            ],
            'consumes' => [
              {
                'name' => 'consumed_links_3',
                'type' => 'type_3',
              },
              {
                'name' => 'consumed_links_4',
                'type' => 'type_4',
              },
            ],
          }
        end

        let(:dummy_with_properties_template) do
          FactoryBot.create(:models_template,
            name: 'dummy_with_properties',
            release: release_model,
            spec_json: dummy_with_properties_template_spec.to_json,
          )
        end

        let(:dummy_with_packages_template) do
          FactoryBot.create(:models_template, name: 'dummy_with_package', release: release_model)
        end

        before do
          release_version_model.add_template(
            FactoryBot.create(:models_template,
              name: 'dummy',
              release: release_model,
              spec_json: dummy_template_spec.to_json,
            ),
          )
          release_version_model.add_template(dummy_with_properties_template)
          release_version_model.add_template(dummy_with_packages_template)

          release = DeploymentPlan::ReleaseVersion.parse(deployment_model, 'name' => 'dummy', 'version' => '0.2-dev')
          deployment.add_release(release)
          stemcell = DeploymentPlan::Stemcell.parse(manifest_hash['stemcells'].first)
          deployment.add_stemcell(stemcell)
          deployment.cloud_planner = DeploymentPlan::CloudManifestParser.new(logger).parse(
            SharedSupport::DeploymentManifestHelper.simple_cloud_config_with_multiple_azs,
          )

          deployment.add_instance_group(instance_group)
          allow(deployment_model).to receive(:current_variable_set).and_return(variable_set)
        end

        context 'when addon does not apply to the instance group' do
          let(:include_spec) do
            { 'deployments' => ['no_findy'] }
          end

          it 'does nothing' do
            expect(instance_group).to_not receive(:add_job)
            addon.add_to_deployment(deployment)
            expect(deployment_model.release_versions).to be_empty
          end
        end

        context 'when addon does not apply to the deployment teams' do
          let(:include_spec) do
            { 'teams' => ['team_2'] }
          end

          it 'does nothing' do
            expect(instance_group).to_not receive(:add_job)
            addon.add_to_deployment(deployment)
            expect(deployment_model.release_versions).to be_empty
          end
        end

        context 'when addon applies to instance group' do
          let(:links_parser) do
            instance_double(Bosh::Director::Links::LinksParser)
          end

          it 'adds addon to instance group' do
            addon.add_to_deployment(deployment)
            deployment_instance_group = deployment.instance_group(instance_group.name)
            expect(deployment_instance_group.jobs.map(&:name)).to eq(%w[dummy dummy_with_properties dummy_with_package])
          end

          it 'parses links using LinksParser' do
            allow(Bosh::Director::Links::LinksParser).to receive(:new).and_return(links_parser)

            expect(links_parser).to receive(:parse_providers_from_job).with(
              jobs[0],
              deployment_model,
              dummy_with_properties_template,
              job_properties: properties,
              instance_group_name: 'foobar',
            )
            expect(links_parser).to receive(:parse_consumers_from_job).with(
              jobs[0],
              deployment_model,
              dummy_with_properties_template,
              instance_group_name: 'foobar',
            )

            expect(links_parser).to receive(:parse_providers_from_job).with(
              jobs[1],
              deployment_model,
              dummy_with_packages_template,
              job_properties: {},
              instance_group_name: 'foobar',
            )
            expect(links_parser).to receive(:parse_consumers_from_job).with(
              jobs[1],
              deployment_model,
              dummy_with_packages_template,
              instance_group_name: 'foobar',
            )

            addon.add_to_deployment(deployment)
          end

          context 'when there is another instance group which is excluded' do
            let(:exclude_spec) do
              { 'jobs' => [{ 'name' => 'dummy_with_properties', 'release' => 'dummy' }] }
            end

            let(:instance_group_spec) do
              jobs = [{ 'name' => 'dummy_with_properties', 'release' => 'dummy' }]
              SharedSupport::DeploymentManifestHelper.simple_instance_group(
                name: 'excluded_ig',
                jobs: jobs,
                azs: ['z1'],
              )
            end

            it 'should not parse providers and consumers for excluded instance group' do
              links_parser = instance_double(Bosh::Director::Links::LinksParser)

              allow(Bosh::Director::Links::LinksParser).to receive(:new).and_return(links_parser)
              allow(links_parser).to receive(:parse_providers_from_job)
              allow(links_parser).to receive(:parse_consumers_from_job)

              expect(links_parser).to_not receive(:parse_providers_from_job).with(
                anything, anything, anything, job_properties: anything, instance_group_name: 'excluded_ig'
              )
              expect(links_parser).to_not receive(:parse_consumers_from_job).with(
                anything, anything, anything, instance_group_name: 'excluded_ig'
              )

              addon.add_to_deployment(deployment)
            end
          end

          context 'when addon job specified does not exist in release' do
            let(:jobs) do
              [
                { 'name' => 'non-existing-job',
                  'release' => 'dummy',
                  'provides_links' => [],
                  'consumes_links' => [] },
                { 'name' => 'dummy_with_package',
                  'release' => 'dummy',
                  'provides_links' => [],
                  'consumes_links' => [] },
              ]
            end

            it 'throws an error' do
              expect do
                addon.add_to_deployment(deployment)
              end.to raise_error Bosh::Director::DeploymentUnknownTemplate, /Can't find job 'non-existing-job'/
            end
          end

          context 'when the addon has top level properties' do
            let(:addon_properties) { { 'addon' => 'properties' } }
            let(:job_properties) { nil }

            let(:jobs) do
              [{
                'name' => 'dummy_with_properties',
                'release' => 'dummy',
                'provides_links' => [],
                'consumes_links' => [],
                'properties' => job_properties,
              }]
            end

            context 'and the addon has job level properties' do
              let(:job_properties) { { 'job' => 'properties' } }
              it 'uses the job level properties' do
                expect(instance_group).to(receive(:add_job)) do |added_job|
                  expect(added_job.properties).to eq('foobar' => { 'job' => 'properties' })
                end
                addon.add_to_deployment(deployment)
              end
            end

            context 'and the addon does not have job level properties' do
              it 'sets the job properties with the top level properties' do
                expect(instance_group).to(receive(:add_job)) do |added_job|
                  expect(added_job.properties).to eq('foobar' => { 'addon' => 'properties' })
                end

                addon.add_to_deployment(deployment)
              end
            end
          end
        end

        context 'when the addon has deployments in include and jobs in exclude' do
          let(:include_spec) do
            { 'deployments' => [deployment_name] }
          end
          let(:exclude_spec) do
            { 'jobs' => [{ 'name' => 'dummy', 'release' => 'dummy' }] }
          end

          it 'adds filtered jobs only' do
            expect(instance_group).not_to receive(:add_job)
            addon.add_to_deployment(deployment)
            expect(deployment_model.release_versions).to be_empty
          end
        end

        context 'when addon does not apply to the availability zones' do
          let(:include_spec) do
            { 'azs' => ['z3'] }
          end

          it 'does nothing' do
            expect(instance_group).to_not receive(:add_job)
            addon.add_to_deployment(deployment)
            expect(deployment_model.release_versions).to be_empty
          end
        end
      end

      describe '#parse' do
        context 'properties' do
          context 'when top level properties are not provided' do
            let(:addon_hash) { { 'name' => 'addon-name' } }

            it 'defaults to an empty hash' do
              allow(Addon).to receive(:new)

              Addon.parse(addon_hash)

              expect(Addon).to have_received(:new).with(
                'addon-name',
                [],
                an_instance_of(Filter),
                an_instance_of(Filter),
                {}
              )
            end
          end

          context 'when top level properties are provided' do
            let(:addon_hash) { { 'name' => 'addon-name', 'properties' => { 'property1' => 'value1' } } }

            it 'passes them through to the addon' do
              allow(Addon).to receive(:new)

              Addon.parse(addon_hash)

              expect(Addon).to have_received(:new).with(
                'addon-name',
                [],
                an_instance_of(Filter),
                an_instance_of(Filter),
                'property1' => 'value1',
              )
            end
          end
        end

        context 'when name, jobs, include' do
          let(:include_hash) do
            { 'jobs' => [] }
          end

          let(:addon_hash) do
            {
              'name' => 'addon-name',
              'jobs' => jobs,
              'include' => include_hash,
            }
          end

          it 'returns addon' do
            expect(Filter).to receive(:parse).with(include_hash, :include, RUNTIME_LEVEL)
            expect(Filter).to receive(:parse).with(nil, :exclude, RUNTIME_LEVEL)
            addon = Addon.parse(addon_hash)
            expect(addon.name).to eq('addon-name')
            expect(addon.jobs.count).to eq(2)
            expect(addon.jobs.map { |job| job['name'] }).to eq(%w[dummy_with_properties dummy_with_package])
          end
        end

        context 'when jobs and include are empty' do
          let(:addon_hash) do
            { 'name' => 'addon-name' }
          end

          it 'returns addon' do
            addon = Addon.parse(addon_hash)
            expect(addon.name).to eq('addon-name')
            expect(addon.jobs.count).to eq(0)
          end
        end

        context 'when name is empty' do
          let(:addon_hash) do
            { 'jobs' => ['addon-name'] }
          end

          it 'errors' do
            error_string = "Required property 'name' was not specified in object ({\"jobs\"=>[\"addon-name\"]})"
            expect { Addon.parse(addon_hash) }.to raise_error(ValidationMissingField, error_string)
          end
        end
      end

      describe '#applies?' do
        context 'when the addon is applicable by deployment name' do
          let(:include_spec) do
            { 'deployments' => [deployment_name] }
          end

          it 'applies' do
            expect(addon.applies?(deployment_name, [], nil)).to eq(true)
          end
        end

        context 'when the addon is not applicable by deployment name' do
          let(:include_spec) do
            { 'deployments' => [deployment_name] }
          end

          it 'does not apply' do
            expect(addon.applies?('blarg', [], nil)).to eq(false)
          end
        end

        context 'when the addon is applicable by team' do
          let(:include_spec) do
            { 'teams' => ['team_1'] }
          end

          it 'applies' do
            expect(addon.applies?(deployment_name, ['team_1'], nil)).to eq(true)
          end
        end

        context 'when the addon is not applicable by team' do
          let(:include_spec) do
            { 'teams' => ['team_5'] }
          end

          it 'does not apply' do
            expect(addon.applies?(deployment_name, ['team_1'], nil)).to eq(false)
          end
        end

        context 'when the addon has empty include' do
          let(:include_spec) do
            {}
          end

          it 'applies' do
            expect(addon.applies?(deployment_name, [], nil)).to eq(true)
          end
        end

        context 'when the addon has empty include and exclude' do
          let(:include_spec) do
            {}
          end
          let(:exclude_spec) do
            {}
          end

          it 'applies' do
            expect(addon.applies?(deployment_name, [], nil)).to eq(true)
          end
        end

        context 'when the addon only excludes' do
          context 'when excluding both job and deployment' do
            let(:exclude_spec) do
              {
                'deployments' => [excluded_deployment_name],
                'jobs' => [{ 'name' => 'excluded_job', 'release' => 'excluded_job_release' }],
              }
            end

            let(:included_instance_group) do
              double(Bosh::Director::DeploymentPlan, has_job?: false)
            end

            let(:excluded_instance_group) do
              excluded = double(Bosh::Director::DeploymentPlan)
              allow(excluded).to receive(:has_job?)
                .with('excluded_job', 'excluded_job_release')
                .and_return(true)
              excluded
            end

            let(:deployment_teams) { [] }

            let(:excluded_deployment_name) { 'excluded_deployment' }
            let(:included_deployment_name) { 'included_deployment' }

            it 'excludes based on deployment or job' do
              expect(
                addon.applies?(
                  excluded_deployment_name,
                  deployment_teams,
                  included_instance_group,
                ),
              ).to eq(true)
              expect(
                addon.applies?(
                  included_deployment_name,
                  deployment_teams,
                  excluded_instance_group,
                ),
              ).to eq(true)
              expect(
                addon.applies?(
                  excluded_deployment_name,
                  deployment_teams,
                  excluded_instance_group,
                ),
              ).to eq(false)
            end
          end
        end

        context 'when the addon has include and exclude' do
          let(:include_spec) do
            { 'deployments' => [deployment_name] }
          end
          context 'when they are the same' do
            let(:exclude_spec) do
              { 'deployments' => [deployment_name] }
            end

            it 'does not apply' do
              expect(addon.applies?(deployment_name, [], nil)).to eq(false)
            end
          end

          context 'when include is for deployment and exclude is for job' do
            let(:exclude_spec) do
              { 'jobs' => [{ 'name' => 'dummy', 'release' => 'dummy' }] }
            end
            let(:release_model) { FactoryBot.create(:models_release, name: 'dummy') }
            let(:release_version_model) do
              FactoryBot.create(:models_release_version,
                version: '0.2-dev', release: release_model,
              )
            end
            let(:instance_group2_spec) do
              SharedSupport::DeploymentManifestHelper.simple_instance_group(
                name: 'foobar1',
                jobs: [{ 'name' => 'dummy_with_properties', 'release' => 'dummy' }],
                azs: ['z2'],
              )
            end
            let(:instance_group2) do
              DeploymentPlan::InstanceGroup.parse(
                deployment,
                instance_group2_spec,
                Config.event_log,
                logger,
              )
            end

            before do
              release_version_model.add_template(FactoryBot.create(:models_template, name: 'dummy', release: release_model))
              release_version_model.add_template(
                FactoryBot.create(:models_template, name: 'dummy_with_properties', release: release_model),
              )

              release = DeploymentPlan::ReleaseVersion.parse(deployment_model, 'name' => 'dummy', 'version' => '0.2-dev')
              deployment.add_release(release)
              stemcell = DeploymentPlan::Stemcell.parse(manifest_hash['stemcells'].first)
              deployment.add_stemcell(stemcell)
              deployment.cloud_planner = DeploymentPlan::CloudManifestParser.new(logger).parse(
                SharedSupport::DeploymentManifestHelper.simple_cloud_config_with_multiple_azs,
              )

              deployment.add_instance_group(instance_group)
              deployment.add_instance_group(instance_group2)
            end

            it 'excludes specified job only' do
              expect(addon.applies?(deployment_name, [], deployment.instance_group('foobar'))).to eq(false)
              expect(addon.applies?(deployment_name, [], deployment.instance_group('foobar1'))).to eq(true)
            end
          end

          context 'when the addon has availability zones' do
            let(:release_model) { FactoryBot.create(:models_release, name: 'dummy') }
            let(:release_version_model) do
              FactoryBot.create(:models_release_version, version: '0.2-dev', release: release_model)
            end
            let(:instance_group_spec) do
              jobs = [{ 'name' => 'dummy', 'release' => 'dummy' }]
              SharedSupport::DeploymentManifestHelper.simple_instance_group(jobs: jobs, azs: ['z1'])
            end
            before do
              release_version_model.add_template(FactoryBot.create(:models_template, name: 'dummy', release: release_model))

              release = DeploymentPlan::ReleaseVersion.parse(deployment_model, 'name' => 'dummy', 'version' => '0.2-dev')
              deployment.add_release(release)
              stemcell = DeploymentPlan::Stemcell.parse(manifest_hash['stemcells'].first)
              deployment.add_stemcell(stemcell)
              deployment.cloud_planner = DeploymentPlan::CloudManifestParser.new(logger).parse(
                SharedSupport::DeploymentManifestHelper.simple_cloud_config_with_multiple_azs,
              )
              deployment.add_instance_group(instance_group)
            end

            context 'when the addon is applicable by availability zones' do
              let(:include_spec) do
                { 'azs' => ['z1'] }
              end
              it 'it applies' do
                expect(addon.applies?(deployment_name, [], deployment.instance_group('foobar'))).to eq(true)
              end
            end

            context 'when the addon is not applicable by availability zones' do
              let(:include_spec) do
                { 'azs' => ['z5'] }
              end
              it 'does not apply' do
                expect(addon.applies?(deployment_name, [], deployment.instance_group('foobar'))).to eq(false)
              end
            end
          end
        end
      end

      describe '#releases' do
        it 'should only return unique releases' do
          expect(addon.releases).to match_array(['dummy'])
        end

        context 'there are no jobs' do
          let(:jobs) do
            []
          end

          it 'should return an empty array of releases' do
            expect(addon.releases).to be_empty
          end
        end
      end
    end
  end
end
