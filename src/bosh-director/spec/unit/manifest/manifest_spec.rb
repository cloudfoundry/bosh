require 'spec_helper'

module Bosh::Director
  describe Manifest do
    subject(:manifest_object) do
      described_class.new(manifest_hash, manifest_text, cloud_config_hash, runtime_config_hash)
    end

    let(:manifest_hash) do
      {}
    end
    let(:manifest_text) { '{}' }
    let(:cloud_config_hash) do
      {}
    end
    let(:runtime_config_hash) do
      {}
    end

    let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }

    let(:consolidated_runtime_config) { instance_double(Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator) }
    let(:cloud_config) { Models::Config.make(:cloud, content: YAML.dump('azs' => [], 'vm_types' => [], 'disk_types' => [], 'networks' => [], 'vm_extensions' => [])) }

    before do
      release_1 = FactoryBot.create(:models_release, name: 'simple')
      FactoryBot.create(:models_release_version, version: 6, release: release_1)
      FactoryBot.create(:models_release_version, version: 9, release: release_1)

      release_1 = FactoryBot.create(:models_release, name: 'hard')
      FactoryBot.create(:models_release_version, version: '1+dev.5', release: release_1)
      FactoryBot.create(:models_release_version, version: '1+dev.7', release: release_1)

      FactoryBot.create(:models_stemcell, name: 'simple', version: '3163', operating_system: 'simple-os')
      FactoryBot.create(:models_stemcell, name: 'simple', version: '3169', operating_system: 'simple-os')

      FactoryBot.create(:models_stemcell, name: 'hard', version: '3146', operating_system: 'hard-os')
      FactoryBot.create(:models_stemcell, name: 'hard', version: '3146.1', operating_system: 'hard-os')

      allow(Bosh::Director::ConfigServer::VariablesInterpolator).to receive(:new).and_return(variables_interpolator)
      allow(variables_interpolator).to receive(:interpolate_cloud_manifest) { |cloud_manifest| Bosh::Common::DeepCopy.copy(cloud_manifest) }
    end

    describe '.load_from_model' do
      let(:deployment_model) { instance_double(Bosh::Director::Models::Deployment) }
      let(:runtime_configs) { [Models::Config.make(type: 'runtime'), Models::Config.make(type: 'runtime')] }
      let(:manifest_hash) do
        { 'name' => 'a_deployment', 'name-1' => 'my-name-1' }
      end
      let(:manifest_text) do
        %(---
         name: a_deployment
         name-1: my-name-1)
      end

      before do
        allow(deployment_model).to receive(:manifest).and_return(manifest_hash.to_json)
        allow(deployment_model).to receive(:manifest_text).and_return(manifest_text)
        allow(deployment_model).to receive(:cloud_configs).and_return([cloud_config])
        allow(deployment_model).to receive(:runtime_configs).and_return(runtime_configs)
        allow(variables_interpolator).to receive(:interpolate_deployment_manifest).and_return(manifest_hash)
        allow(Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator).to receive(:new).with(runtime_configs).and_return(consolidated_runtime_config)
        allow(consolidated_runtime_config).to receive(:raw_manifest).and_return('raw_runtime' => '((foo))')
        allow(consolidated_runtime_config).to receive(:interpolate_manifest_for_deployment).and_return('my_runtime' => 'foo_value')
      end

      it 'creates a manifest object from a manifest, a cloud config, and an aggregation of the runtime configs' do
        result =  Manifest.load_from_model(deployment_model)
        expect(result.manifest_hash).to eq('name' => 'a_deployment', 'name-1' => 'my-name-1')
        expect(result.manifest_text).to eq(manifest_text)
        expect(result.cloud_config_hash).to eq(cloud_config.raw_manifest)
        expect(result.runtime_config_hash).to eq('my_runtime' => 'foo_value')
      end

      context 'when empty manifests exist' do
        before do
          allow(deployment_model).to receive(:manifest).and_return(nil)
          allow(deployment_model).to receive(:manifest_text).and_return(nil)
          allow(deployment_model).to receive(:cloud_configs).and_return([cloud_config])
          allow(deployment_model).to receive(:runtime_configs).and_return([])
          allow(Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator).to receive(:new).with([]).and_return(consolidated_runtime_config)

          allow(consolidated_runtime_config).to receive(:raw_manifest).and_return({})
          allow(consolidated_runtime_config).to receive(:interpolate_manifest_for_deployment).and_return({})
          allow(variables_interpolator).to receive(:interpolate_deployment_manifest).and_return({})
        end
      end

      context 'when resolving manifest' do
        before do
          allow(Api::CloudConfigManager).to receive(:interpolated_manifest).and_return({})
          allow(deployment_model).to receive(:manifest).and_return("{'name': 'surfing_deployment', 'smurf': '((smurf_placeholder))'}")
          allow(deployment_model).to receive(:cloud_configs).and_return([cloud_config])
        end

        it 'calls the manifest resolver with correct values' do
          expect(variables_interpolator).to receive(:interpolate_deployment_manifest).with({ 'name' => 'surfing_deployment', 'smurf' => '((smurf_placeholder))'}).and_return('smurf' => 'blue')
          manifest_object_result = Manifest.load_from_model(deployment_model)

          expect(manifest_object_result.manifest_hash).to eq('smurf' => 'blue')
          expect(manifest_object_result.cloud_config_hash).to eq(cloud_config.raw_manifest)
          expect(manifest_object_result.runtime_config_hash).to eq('my_runtime' => 'foo_value')
        end

        it 'respects resolve_interpolation flag when calling the manifest resolver' do
          manifest_object_result = Manifest.load_from_model(deployment_model, resolve_interpolation: false)
          expect(variables_interpolator).to_not receive(:interpolate_deployment_manifest)
          expect(consolidated_runtime_config).to_not receive(:interpolate_manifest_for_deployment)

          expect(manifest_object_result.manifest_hash).to eq('name' => 'surfing_deployment', 'smurf' => '((smurf_placeholder))')
          expect(manifest_object_result.cloud_config_hash).to eq(cloud_config.raw_manifest)
          expect(manifest_object_result.runtime_config_hash).to eq('raw_runtime' => '((foo))')
        end
      end
    end

    describe '.load_from_hash' do
      let(:cloud_config) do
        Models::Config.make(:cloud, content: YAML.dump('azs' => ['my-az'],
                                                       'vm_types' => ['my-vm-type'],
                                                       'disk_types' => ['my-disk-type'],
                                                       'networks' => ['my-net'],
                                                       'vm_extensions' => ['my-extension']))
      end
      let(:runtime_configs) { [Models::Config.make(type: 'runtime'), Models::Config.make(type: 'runtime')] }

      let(:runtime_config_hash) do
        { 'raw_runtime' => '((foo))' }
      end
      let(:cloud_config_hash) { cloud_config.raw_manifest }
      let(:manifest_text) do
        %(---
        name: minimal
        releases:
        - name: simple
          version: latest
       )
      end

      before do
        allow(variables_interpolator).to receive(:interpolate_deployment_manifest).with({}).and_return({})
        allow(Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator).to receive(:new).with(runtime_configs).and_return(consolidated_runtime_config)
        allow(consolidated_runtime_config).to receive(:raw_manifest).and_return(runtime_config_hash)
        allow(consolidated_runtime_config).to receive(:interpolate_manifest_for_deployment).and_return(runtime_config_hash)
      end

      it 'creates a manifest object from a cloud config, a manifest text, and a runtime config' do
        expect(
          Manifest.load_from_hash(manifest_hash, manifest_text, [cloud_config], runtime_configs).to_yaml,
        ).to eq(manifest_object.to_yaml)
      end

      context 'when resolving manifest' do
        let(:passed_in_manifest_hash) do
          { 'smurf' => '((smurf_placeholder))' }
        end

        before do
          allow(Api::CloudConfigManager).to receive(:interpolated_manifest).and_return({})
        end

        it 'calls the manifest resolver with correct values' do
          expect(variables_interpolator).to receive(:interpolate_deployment_manifest).with({ 'smurf' => '((smurf_placeholder))' }).and_return('smurf' => 'blue')
          manifest_object_result = Manifest.load_from_hash(passed_in_manifest_hash, YAML.dump(passed_in_manifest_hash), [cloud_config], runtime_configs)
          expect(manifest_object_result.manifest_hash).to eq('smurf' => 'blue')
          expect(manifest_object_result.cloud_config_hash).to eq(cloud_config.raw_manifest)
          expect(manifest_object_result.runtime_config_hash).to eq(runtime_config_hash)
        end

        it 'respects resolve_interpolation flag when calling the manifest resolver' do
          expect(variables_interpolator).to_not receive(:interpolate_deployment_manifest)

          manifest_object_result = Manifest.load_from_hash(passed_in_manifest_hash, YAML.dump(passed_in_manifest_hash), [cloud_config], runtime_configs, resolve_interpolation: false)
          expect(manifest_object_result.manifest_hash).to eq('smurf' => '((smurf_placeholder))')
          expect(manifest_object_result.cloud_config_hash).to eq(cloud_config.raw_manifest)
          expect(manifest_object_result.runtime_config_hash).to eq(runtime_config_hash)
        end
      end
    end

    describe '.generate_empty_manifest' do
      before do
        allow(Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator).to receive(:new).with([]).and_return(consolidated_runtime_config)
        allow(consolidated_runtime_config).to receive(:raw_manifest).and_return({})
      end

      it 'generates empty manifests' do
        result_manifest = Manifest.generate_empty_manifest
        expect(result_manifest.manifest_hash).to eq({})
        expect(result_manifest.manifest_text).to eq('{}')
        expect(result_manifest.cloud_config_hash).to eq(nil)
        expect(result_manifest.runtime_config_hash).to eq({})
      end
    end

    describe 'resolve_aliases' do
      context 'releases' do
        context 'when manifest has releases with version latest' do
          let(:provided_hash) do
            {
              'releases' => [
                { 'name' => 'simple', 'version' => 'latest' },
                { 'name' => 'hard', 'version' => 'latest' },
              ],
            }
          end

          let(:manifest_hash) { provided_hash }

          it 'replaces latest with the latest version number' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['releases']).to eq(
              [{ 'name' => 'simple', 'version' => '9' },
               { 'name' => 'hard', 'version' => '1+dev.7' }],
            )
            expect(manifest_object.manifest_hash['releases']).to eq(
              [{ 'name' => 'simple', 'version' => '9' },
               { 'name' => 'hard', 'version' => '1+dev.7' }],
            )
          end
        end

        context "when manifest has releases with version using '.latest' suffix" do
          let(:provided_hash) do
            {
              'releases' => [
                { 'name' => 'simple', 'version' => '9.latest' },
                { 'name' => 'hard', 'version' => '1.latest' },
              ],
            }
          end

          let(:manifest_hash) { provided_hash }

          it 'should replace version with the relative latest' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['releases']).to eq(
              [{ 'name' => 'simple', 'version' => '9' },
               { 'name' => 'hard', 'version' => '1+dev.7' }],
            )
            expect(manifest_object.manifest_hash['releases']).to eq(
              [{ 'name' => 'simple', 'version' => '9' },
               { 'name' => 'hard', 'version' => '1+dev.7' }],
            )
          end
        end

        context 'when manifest has no alias' do
          let(:provided_hash) do
            {
              'releases' => [
                { 'name' => 'simple', 'version' => 9 },
                { 'name' => 'hard', 'version' => '42' },
              ],
            }
          end

          let(:manifest_hash) { provided_hash }

          it 'leaves it as it is and converts to string' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['releases']).to eq(
              [{ 'name' => 'simple', 'version' => '9' },
               { 'name' => 'hard', 'version' => '42' }],
            )
            expect(manifest_object.manifest_hash['releases']).to eq(
              [{ 'name' => 'simple', 'version' => '9' },
               { 'name' => 'hard', 'version' => '42' }],
            )
          end
        end

        context 'when manifest has uninterpolated releases property' do
          let(:manifest_hash) do
            {
              'releases' => '((nope))',
            }
          end

          it 'keeps the uninterpolated value' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['releases']).to eq('((nope))')
            expect(manifest_object.manifest_hash['releases']).to eq('((nope))')
          end
        end

        context 'when manifest has uninterpolated release items' do
          let(:manifest_hash) do
            {
              'releases' => [
                '((nope))',
              ],
            }
          end

          it 'keeps the uninterpolated value' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['releases']).to eq(['((nope))'])
            expect(manifest_object.manifest_hash['releases']).to eq(['((nope))'])
          end
        end
      end

      context 'stemcells' do
        context 'when manifest has stemcells with version latest' do
          let(:manifest_hash) do
            {
              'stemcells' => [
                { 'name' => 'simple', 'version' => 'latest' },
                { 'name' => 'hard', 'version' => 'latest' },
              ],
            }
          end

          it 'replaces latest with the latest version number' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['stemcells']).to eq(
              [{ 'name' => 'simple', 'version' => '3169', 'os'=>'simple-os' },
               { 'name' => 'hard', 'version' => '3146.1', 'os'=>'hard-os' }],
            )
          end
        end

        context 'when manifest has stemcell with version prefix' do
          let(:manifest_hash) do
            {
              'stemcells' => [
                { 'name' => 'simple', 'version' => '3169.latest' },
                { 'name' => 'hard', 'version' => '3146.latest' },
              ],
            }
          end

          it 'replaces prefixed-latest with the latest version number' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['stemcells']).to eq(
              [{ 'name' => 'simple', 'version' => '3169', 'os'=>'simple-os' },
               { 'name' => 'hard', 'version' => '3146.1', 'os'=>'hard-os' }],
            )
          end
        end

        context 'when manifest has stemcell with no alias' do
          let(:manifest_hash) do
            {
              'stemcells' => [
                { 'name' => 'simple', 'version' => 42 },
                { 'name' => 'hard', 'version' => 'latest' },
              ],
            }
          end

          it 'leaves it as it is and converts to string' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['stemcells']).to eq(
              [{ 'name' => 'simple', 'version' => '42' },
               { 'name' => 'hard', 'version' => '3146.1', 'os'=>'hard-os' }],
            )
          end
        end

        context 'when manifest has uninterpolated stemcells property' do
          let(:manifest_hash) do
            {
              'stemcells' => '((foo))',
            }
          end

          it 'keeps the uninterpolated value' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['stemcells']).to eq('((foo))')
          end
        end

        context 'when manifest has uninterpolated stemcell items' do
          let(:manifest_hash) do
            {
              'stemcells' => ['((foo))'],
            }
          end

          it 'keeps the uninterpolated value' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['stemcells']).to eq(['((foo))'])
          end
        end

        context 'when manifest has stemcells specified by name without os' do
          let(:manifest_hash) do
            {
              'stemcells' => [
                { 'name' => 'simple', 'version' => 'latest' },
                { 'name' => 'hard', 'version' => 'latest' },
              ],
            }
          end

          it 'adds the os' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['stemcells']).to eq(
              [{ 'name' => 'simple', 'version' => '3169', 'os' => 'simple-os' },
                { 'name' => 'hard', 'version' => '3146.1', 'os' => 'hard-os' }],
            )
          end
        end
      end
    end

    describe '#diff' do
      subject(:new_manifest_object) do
        described_class.new(
          new_manifest_hash,
          YAML.dump(new_manifest_hash),
          new_cloud_config_hash,
          new_runtime_config_hash,
        )
      end

      let(:new_manifest_hash) do
        {
          'releases' => [],
          'properties' => {
            'something' => 'worth-redacting',
          },
          'jobs' => [
            {
              'name' => 'useful',
              'properties' => {
                'inner' => 'secrets',
              },
            },
          ],
        }
      end

      let(:new_cloud_config_hash) { cloud_config_hash }
      let(:new_runtime_config_hash) { runtime_config_hash }
      let(:diff) do
        manifest_object.diff(new_manifest_object, redact, []).map(&:text).join("\n")
      end

      context 'when called' do
        let(:redact) { true }
        let(:mock_changeset) { instance_double(Bosh::Director::Changeset) }
        let(:diff_return) { double(order: '') }

        it 'calls changeset with correct parameters' do
          expect(Bosh::Director::Changeset).to receive(:new).and_return(mock_changeset)
          expect(mock_changeset).to receive(:diff).with(true).and_return(diff_return)
          expect(diff_return).to receive(:order)
          expect(manifest_object).to receive(:to_hash_filter_addons).and_return({})
          expect(new_manifest_object).to receive(:to_hash_filter_addons).and_return({})
          manifest_object.diff(new_manifest_object, redact, [])
        end
      end

      context 'when redact is true' do
        let(:redact) { true }

        it 'redacts properties' do
          expect(diff).to include('<redacted>')
        end
      end

      context 'when redact is false' do
        let(:redact) { false }

        it 'doesn\'t redact properties' do
          expect(diff).to_not include('<redacted>')
        end
      end
    end

    describe 'to_hash' do
      let(:manifest_hash) do
        {
          'releases' => [
            { 'name' => 'simple', 'version' => '2' },
          ],
          'properties' => {
            'test' => '((test_placeholder))',
          },
        }
      end

      let(:runtime_config_hash) do
        {
          'releases' => [
            { 'name' => 'runtime_release', 'version' => '2' },
          ],
          'addons' => [
            {
              'name' => 'test',
              'properties' => {
                'test2' => '((test2_placeholder))',
              },
            },
          ],
        }
      end

      it 'returns the merged hashes' do
        expect(manifest_object.to_hash).to eq('releases' => [
                                                { 'name' => 'simple', 'version' => '2' },
                                                { 'name' => 'runtime_release', 'version' => '2' },
                                              ],
                                              'addons' => [
                                                {
                                                  'name' => 'test',
                                                  'properties' => {
                                                    'test2' => '((test2_placeholder))',
                                                  },
                                                },
                                              ],
                                              'properties' => {
                                                'test' => '((test_placeholder))',
                                              })
      end

      context 'when deployment manifest has no releases' do
        let(:manifest_hash) do
          {
            'name' => 'test_deployment',
            'instance_groups' => [
              {
                'name' => 'test_instance_group',
                'jobs' => [],
              },
            ],
          }
        end
        let(:runtime_config_hash) do
          {
            'releases' => [
              { 'name' => 'runtime_release', 'version' => '2' },
            ],
            'addons' => [
              {
                'name' => 'test',
                'jobs' => [{
                  'name' => 'addon_job',
                  'release' => 'runtime_release',
                }],
              },
            ],
          }
        end

        it 'returns manifest with addon and release' do
          filtered_manifest = manifest_object.to_hash_filter_addons([])
          expect(filtered_manifest['releases']).to eq(runtime_config_hash['releases'])
          expect(filtered_manifest['addons']).to eq(runtime_config_hash['addons'])
        end
      end

      context 'when both deployment manifest and runtime config contain addons' do
        before(:each) do
          manifest_hash.merge!(
            'addons' => [{ 'name' => 'deployment_level_addon' }],
          )
        end
        it 'includes the merged addons' do
          expect(manifest_object.to_hash['addons']).to match_array(
            [{ 'name' => 'test', 'properties' => { 'test2' => '((test2_placeholder))' } },
             { 'name' => 'deployment_level_addon' }],
          )
        end
      end

      context 'when tags are set' do
        before(:each) do
          manifest_hash.merge!(
            'tags' => { 'tag_1' => 'deployment_level_tag' },
          )
        end
        context 'when deployment manifest contains tags' do
          it 'includes the deployment level tag' do
            expect(manifest_object.to_hash['tags']).to eq(
              'tag_1' => 'deployment_level_tag',
            )
          end
        end
        context 'when both deployment manifest and runtime config contain tags' do
          context 'when the tags are different' do
            before(:each) do
              runtime_config_hash.merge!(
                'tags' => { 'tag_2' => 'runtime_level_tag' },
              )
            end
            it 'includes the merged tags' do
              expect(manifest_object.to_hash['tags']).to eq(
                'tag_1' => 'deployment_level_tag',
                'tag_2' => 'runtime_level_tag',
              )
            end
          end
          context 'when the tags have the same key' do
            before(:each) do
              runtime_config_hash.merge!(
                'tags' =>
                {
                  'tag_1' => 'runtime_level_tag',
                },
              )
            end
            it 'includes the deployment level tag' do
              expect(manifest_object.to_hash['tags']).to eq(
                'tag_1' => 'deployment_level_tag',
              )
            end
          end
          context 'when the runtime config tags are nil' do
            before(:each) do
              runtime_config_hash.merge!(
                'tags' => nil,
              )
            end
            it 'includes the deployment level tag' do
              expect(manifest_object.to_hash['tags']).to eq(
                'tag_1' => 'deployment_level_tag',
              )
            end
          end
          context 'when the deployment manifest tags are nil' do
            before(:each) do
              manifest_hash['tags'] = nil
              runtime_config_hash.merge!(
                'tags' =>
                {
                  'tag_1' => 'runtime_level_tag',
                },
              )
            end
            it 'includes the runtime level tag' do
              expect(manifest_object.to_hash['tags']).to eq(
                'tag_1' => 'runtime_level_tag',
              )
            end
          end
        end
      end

      context 'when runtime config contains an addon' do
        let(:manifest_hash) do
          {
            'name' => 'test_deployment',
            'releases' => [
              { 'name' => 'simple', 'version' => '2' },
            ],
            'instance_groups' => [
              {
                'name' => 'test_instance_group',
                'jobs' => [],
              },
            ],
          }
        end
        let(:runtime_config_hash) do
          {
            'releases' => [
              { 'name' => 'runtime_release', 'version' => '2' },
            ],
            'addons' => [
              {
                'name' => 'test',
                'jobs' => [{
                  'name' => 'addon_job',
                  'release' => 'runtime_release',
                }],
              },
            ],
          }
        end

        context 'that is not applicable to the deployment name' do
          before do
            runtime_config_hash['addons'][0]['exclude'] = {
              'deployments' => ['test_deployment'],
            }
          end

          it 'returns the merged hashes without the addon and release' do
            expect(manifest_object.to_hash_filter_addons([])).to eq(manifest_hash)
          end
        end

        context 'that is not applicable to the deployment by excluding the instance_group name' do
          before do
            runtime_config_hash['addons'][0]['exclude'] = {
              'instance_groups' => ['test_instance_group'],
            }
          end

          it 'returns the merged hashes without the addon and release' do
            expect(manifest_object.to_hash_filter_addons([])).to eq(manifest_hash)
          end
        end

        context 'that is not applicable to the deployment by defined team' do
          let(:non_eligable_team) { FactoryBot.create(:models_team, name: 'non-eligable-team') }
          before do
            runtime_config_hash['addons'][0]['exclude'] = {
              'teams' => [
                'non-eligable-team',
              ],
            }
          end

          it 'returns the merged hashes without the addon and release' do
            expect(manifest_object.to_hash_filter_addons([non_eligable_team])).to eq(manifest_hash)
          end
        end
      end

      context 'when runtime config contains same release/version or variables as deployment manifest' do
        let(:manifest_hash) do
          {
            'releases' => [
              { 'name' => 'simple', 'version' => '2' },
              { 'name' => 'hard', 'version' => 'latest' },
            ],
            'variables' => [
              { 'name' => 'variable', 'type' => 'password' },
              { 'name' => 'another_variable', 'type' => 'smurfs' },
            ],
          }
        end

        let(:runtime_config_hash) do
          {
            'releases' => [
              { 'name' => 'simple', 'version' => '2' },
            ],
            'variables' => [
              { 'name' => 'variable', 'type' => 'password' },
            ],
          }
        end

        it 'includes only one copy of the release in to_hash output' do
          expect(manifest_object.to_hash['releases']).to eq(
            [{ 'name' => 'simple', 'version' => '2' },
             { 'name' => 'hard', 'version' => 'latest' }],
          )
        end

        it 'includes only one copy of the variable in to_hash output' do
          variables_hash = manifest_object.to_hash['variables']
          expect(variables_hash.length).to eq(2)
          expect(variables_hash).to include('name' => 'variable', 'type' => 'password')
          expect(variables_hash).to include('name' => 'another_variable', 'type' => 'smurfs')
        end
      end
    end
  end
end
