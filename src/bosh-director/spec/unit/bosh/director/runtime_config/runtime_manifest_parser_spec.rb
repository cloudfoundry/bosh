require 'spec_helper'

module Bosh::Director
  describe RuntimeConfig::RuntimeManifestParser do
    subject(:parser) do
      variables_spec_parser = Bosh::Director::DeploymentPlan::VariablesSpecParser.new(per_spec_logger, FactoryBot.create(:models_deployment))
      described_class.new(per_spec_logger, variables_spec_parser)
    end
    let(:planner_options) do
      {}
    end
    let(:event_log) { Config.event_log }

    describe '#parse' do
      let(:runtime_manifest) { SharedSupport::DeploymentManifestHelper.simple_runtime_config }

      it "raises RuntimeInvalidReleaseVersion if a release uses version 'latest'" do
        runtime_manifest['releases'][0]['version'] = 'latest'
        expect { subject.parse(runtime_manifest) }.to raise_error(Bosh::Director::RuntimeInvalidReleaseVersion)
      end

      it "raises RuntimeInvalidReleaseVersion if a release uses relative version '.latest'" do
        runtime_manifest['releases'][0]['version'] = '3146.latest'
        expect { subject.parse(runtime_manifest) }.to raise_error(Bosh::Director::RuntimeInvalidReleaseVersion)
      end

      it "raises AddonReleaseNotListedInReleases if addon job's release is not listed in releases" do
        runtime_manifest = SharedSupport::DeploymentManifestHelper.runtime_config_with_addon
        runtime_manifest['releases'][0]['name'] = 'weird_name'
        expect { subject.parse(runtime_manifest) }.to raise_error(AddonReleaseNotListedInReleases)
      end

      context 'when runtime manifest does not have an include or exclude section' do
        let(:runtime_manifest) { SharedSupport::DeploymentManifestHelper.runtime_config_with_addon }

        it 'appends addon jobs to deployment job templates and addon properties to deployment job properties' do
          expect(Addon::Filter).to receive(:new).with(
            jobs: [], instance_groups: [], deployment_names: [], stemcells: [],
            networks: [], teams: [], availability_zones: [], lifecycle_type: '', filter_type: :include
          )
          expect(Addon::Filter).to receive(:new).with(
            jobs: [], instance_groups: [], deployment_names: [], stemcells: [],
            networks: [], teams: [], availability_zones: [], lifecycle_type: '', filter_type: :exclude
          )

          result = subject.parse(runtime_manifest)

          releases = result.releases
          expect(releases.count).to eq(1)
          expect(releases.first.name).to eq(runtime_manifest['releases'][0]['name'])
          expect(releases.first.version).to eq(runtime_manifest['releases'][0]['version'])

          expect(result.addons.count).to eq(1)
          addon = result.addons.first
          expect(addon.name).to eq('addon1')
          expect(addon.jobs).to eq(
            [
              {
                'name' => 'dummy_with_properties',
                'release' => 'dummy2',
                'provides' => {},
                'consumes' => {},
                'properties' => {
                  'dummy_with_properties' => {
                    'echo_value' => 'addon_prop_value',
                  },
                },
              },
              {
                'name' => 'dummy_with_package',
                'release' => 'dummy2',
                'provides' => {},
                'consumes' => {},
                'properties' => nil,
              },
            ],
          )
        end
      end

      context 'when runtime manifest has an include section' do
        let(:runtime_manifest) { SharedSupport::DeploymentManifestHelper.runtime_config_with_addon }

        context 'when deployment name is in the includes.deployments section' do
          let(:runtime_manifest) do
            runtime_manifest = SharedSupport::DeploymentManifestHelper.runtime_config_with_addon
            runtime_manifest['addons'].first.merge!(
              'include' => {
                'deployments' => ['dep1'],
              },
            )
            runtime_manifest
          end

          it 'returns deployment associated with addon' do
            expect(Addon::Filter).to receive(:new).with(
              jobs: [], instance_groups: [], deployment_names: ['dep1'], stemcells: [],
              networks: [], teams: [], availability_zones: [], lifecycle_type: '', filter_type: :include
            )
            expect(Addon::Filter).to receive(:new).with(
              jobs: [], instance_groups: [], deployment_names: [], stemcells: [],
              networks: [], teams: [], availability_zones: [], lifecycle_type: '', filter_type: :exclude
            )
            subject.parse(runtime_manifest)
          end
        end
      end

      context 'when runtime manifest has an exclude section' do
        let(:runtime_manifest) { SharedSupport::DeploymentManifestHelper.runtime_config_with_addon_excludes }

        context 'when deployment name is in the includes.deployments section' do
          let(:runtime_manifest) do
            runtime_manifest = SharedSupport::DeploymentManifestHelper.runtime_config_with_addon
            runtime_manifest['addons'].first.merge!(
              'exclude' => {
                'deployments' => ['dep1'],
              },
            )
            runtime_manifest
          end

          it 'returns deployment associated with addon' do
            expect(Addon::Filter).to receive(:new).with(
              jobs: [], instance_groups: [], deployment_names: [], stemcells: [],
              networks: [], teams: [], availability_zones: [], lifecycle_type: '', filter_type: :include
            )
            expect(Addon::Filter).to receive(:new).with(
              jobs: [], instance_groups: [], deployment_names: ['dep1'], stemcells: [],
              networks: [], teams: [], availability_zones: [], lifecycle_type: '', filter_type: :exclude
            )

            subject.parse(runtime_manifest)
          end
        end

        context 'when jobs section present' do
          context 'when only job name is provided' do
            let(:runtime_manifest) do
              runtime_manifest = SharedSupport::DeploymentManifestHelper.runtime_config_with_addon
              runtime_manifest['addons'].first.merge!(
                'exclude' => {
                  'jobs' => [{ 'name' => 'foobar' }],
                },
              )
              runtime_manifest
            end
            it 'throws an error' do
              expect { subject.parse(runtime_manifest) }.to raise_error(AddonIncompleteFilterJobSection)
            end
          end

          context 'when only release is provided' do
            let(:runtime_manifest) do
              runtime_manifest = SharedSupport::DeploymentManifestHelper.runtime_config_with_addon
              runtime_manifest['addons'].first.merge!(
                'exclude' => {
                  'jobs' => [{ 'release' => 'foobar' }],
                },
              )
              runtime_manifest
            end
            it 'throws an error' do
              expect { subject.parse(runtime_manifest) }.to raise_error(AddonIncompleteFilterJobSection)
            end
          end
        end

        context 'when variables section present' do
          let(:runtime_manifest) do
            runtime_manifest = SharedSupport::DeploymentManifestHelper.runtime_config_with_addon

            variables_spec = [
              { 'name' => 'var_a', 'type' => 'a' },
              'name' => 'var_b',
              'type' => 'b',
              'options' => { 'x' => 2 },
            ]
            runtime_manifest.merge!('variables' => variables_spec)

            runtime_manifest
          end
          it 'parses variables' do
            result = subject.parse(runtime_manifest)

            variables = result.variables
            expect(variables.spec.length).to eq(2)

            expect(variables.get_variable('var_a')).to eq('name' => 'var_a', 'type' => 'a')
            expect(variables.get_variable('var_b')).to eq('name' => 'var_b', 'type' => 'b', 'options' => { 'x' => 2 })
          end
        end
      end

      context 'when the runtime manifest does not have a releases section' do
        let(:runtime_manifest) { { 'tags' => ['a'] } }

        it 'does not fail' do
          result = subject.parse(runtime_manifest)
          releases = result.releases
          expect(releases.count).to eq(0)
        end
      end
    end
  end
end
