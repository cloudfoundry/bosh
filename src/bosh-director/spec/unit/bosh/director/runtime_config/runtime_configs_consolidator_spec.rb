require 'spec_helper'

module Bosh::Director
  describe RuntimeConfig::RuntimeConfigsConsolidator do
    subject(:consolidator) { described_class.new(runtime_configs) }
    let(:rc_model_1) { instance_double(Bosh::Director::Models::Config)}
    let(:rc_model_2) { instance_double(Bosh::Director::Models::Config)}
    let(:rc_model_3) { instance_double(Bosh::Director::Models::Config)}
    let(:runtime_configs) { [ rc_model_1, rc_model_2, rc_model_3] }

    describe '#create_from_model_ids' do
      let(:runtime_configs) do
        [
          instance_double(Bosh::Director::Models::Config),
          instance_double(Bosh::Director::Models::Config),
        ]
      end

      let(:runtime_config_ids) { [1, 21, 65] }
      before do
        allow(Bosh::Director::Models::Config).to receive(:find_by_ids).with(runtime_config_ids).and_return(runtime_configs)
      end

      it 'calls initialize with the models' do
        expect(Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator).to receive(:new).with(runtime_configs)
        Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator.create_from_model_ids(runtime_config_ids)

      end
    end

    describe '#raw_manifest' do
      before do
        allow(rc_model_1).to receive(:raw_manifest).and_return(runtime_config_1)
        allow(rc_model_2).to receive(:raw_manifest).and_return(runtime_config_2)
        allow(rc_model_3).to receive(:raw_manifest).and_return(runtime_config_3)
      end

      let(:release_1) do
        { 'name' => 'release_1', 'version' => '1' }
      end
      let(:release_2) do
        { 'name' => 'release_2', 'version' => '2' }
      end
      let(:release_3) do
        { 'name' => 'release_3', 'version' => '3' }
      end
      let(:release_4) do
        { 'name' => 'release_4', 'version' => '4' }
      end
      let(:release_5) do
        { 'name' => 'release_5', 'version' => '5' }
      end

      let(:addon_1) do
        {
          'name' => 'addon_1',
          'jobs' => [
            { 'name' => 'a', 'release' => 'release_1' },
            { 'name' => 'b', 'release' => 'release_2' },
          ],
          'properties' => { 'p_1_1' => { 'p_1_2' => 'p_1_3' } },
        }
      end

      let(:addon_2) do
        {
          'name' => 'addon_2',
          'jobs' => [
            { 'name' => 'c', 'release' => 'release_3' },
            { 'name' => 'd', 'release' => 'release_4' },
          ],
          'properties' => { 'p_2_1' => { 'p_2_2' => 'p_2_3' } },
        }
      end

      let(:addon_3) do
        {
          'name' => 'addon_3',
          'jobs' => [
            { 'name' => 'c', 'release' => 'release_5' },
          ],
          'properties' => { 'p_3_1' => { 'p_3_2' => 'p_3_4' } },
        }
      end

      let(:addon_4) do
        {
          'name' => 'addon_4',
          'jobs' => [
            { 'name' => 'd', 'release' => 'release_6' },
          ],
          'properties' => { 'p_4_1' => { 'p_4_2' => 'p_4_2' } },
        }
      end

      let(:variable_1) do
        {
          'name' => '/dns_healthcheck_tls_ca',
          'type' => 'certificate',
          'options' => { 'is_ca' => true, 'common_name' => 'dns-healthcheck-tls-ca' },
        }
      end

      let(:variable_2) do
        {
          'name' => '/dns_healthcheck_server_tls',
          'type' => 'certificate',
          'options' => { 'is_ca' => true, 'common_name' => 'health.bosh-dns', 'extended_key_usage' => ['server_auth'] },
        }
      end

      let(:variable_3) do
        {
          'name' => '/dns_healthcheck_client_tls',
          'type' => 'certificate',
          'options' => { 'is_ca' => true, 'common_name' => 'health.bosh-dns', 'extended_key_usage' => ['client_auth'] },
        }
      end

      let(:runtime_config_1) do
        {
          'releases' => [
            release_1,
            release_2,
          ],
          'addons' => [
            addon_1,
            addon_2,
          ],
        }
      end

      let(:runtime_config_2) do
        {
          'releases' => [
            release_3,
            release_4,
          ],
          'addons' => [
            addon_3,
          ],
          'variables' => [
            variable_1,
            variable_2,
          ],
        }
      end

      let(:runtime_config_3) do
        {
          'releases' => [
            release_5,
          ],
          'addons' => [
            addon_4,
          ],
          'variables' => [
            variable_3,
          ],
        }
      end

      let(:consolidated_manifest) do
        {
          'releases' => [
            release_1,
            release_2,
            release_3,
            release_4,
            release_5,
          ],
          'addons' => [
            addon_1,
            addon_2,
            addon_3,
            addon_4,
          ],
          'variables' => [
            variable_1,
            variable_2,
            variable_3,
          ],
        }
      end

      it 'returns a consolidated manifest consisting of the specified configs manifests' do
        expect(consolidator.raw_manifest).to eq(consolidated_manifest)
      end

      context 'when there are no addons and variables in runtime configs' do
        let(:rc_model) { instance_double(Bosh::Director::Models::Config) }
        let(:runtime_configs) { [rc_model] }
        let(:runtime_config) do
          {
            'releases' => [
              release_1,
              release_2,
            ],
          }
        end

        before do
          allow(rc_model).to receive(:raw_manifest).and_return(runtime_config)
        end

        it 'returns no empty arrays for addons and variables' do
          expect(consolidator.raw_manifest.keys).to contain_exactly('releases')
        end
      end

      context 'when there are no models' do
        let(:runtime_configs) { []}

        it 'returns an empty hash' do
          expect(consolidator.raw_manifest).to eq({})
        end
      end

      context 'when releases is not an array' do
        let(:runtime_config_1) do
          {
            'releases' => "omg",
            'addons' => [
              addon_1,
              addon_2
            ],
          }
        end

        it 'returns an error' do
          expect {
            consolidator.raw_manifest
          }.to raise_error(Bosh::Director::ValidationInvalidType,
                           /Property 'releases' value \("omg"\) did not match the required type 'Array'/)
        end

      end

      context 'when addons is not an array' do
        let(:runtime_config_1) do
          {
            'releases' => [
              release_1,
              release_2
            ],
            'addons' => 2,
          }
        end

        it 'returns an error ' do
          expect {
            consolidator.raw_manifest
          }.to raise_error(Bosh::Director::ValidationInvalidType,
                           /Property 'addons' value \(2\) did not match the required type 'Array'/)
        end

      end

      context 'when more than one runtime config defines the tag key' do
        let(:runtime_config_2) do
          {
            'tags' => { 'foo' => 'bar' },
          }
        end

        let(:runtime_config_3) do
          {
            'tags' => { 'moop' => 'yarb' },
          }
        end

        it 'returns an error' do
          expect {
            consolidator.raw_manifest
          }.to raise_error RuntimeConfigParseError, "Runtime config 'tags' key cannot be defined in multiple runtime configs."
        end
      end

    end

    describe '#interpolate_manifest_for_deployment' do
      let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }
      let(:mock_manifest) do
        { name: '((manifest_name))' }
      end
      let(:deployment_name) { 'some_deployment_name' }
      let(:interpolated_runtime_config) do
        { name: 'interpolated manifest' }
      end

      before do
        allow(Bosh::Director::ConfigServer::VariablesInterpolator).to receive(:new).and_return(variables_interpolator)
        allow(variables_interpolator).to receive(:interpolate_runtime_manifest).with(mock_manifest, deployment_name).and_return(interpolated_runtime_config)
        allow(consolidator).to receive(:raw_manifest).and_return(mock_manifest)
      end

      it 'calls manifest resolver and returns its result' do
        result = consolidator.interpolate_manifest_for_deployment(deployment_name)
        expect(result).to eq(interpolated_runtime_config)
      end
    end

    describe '#tags' do
      let(:deployment_name) { 'some_deployment_name' }
      let(:interpolated_runtime_config) do
        {
          'releases' => [],
          'addons' => [],
          'tags' => runtime_config_tags,
        }
      end

      let(:runtime_config_tags) do
        { 'foo' => 'bar' }
      end

      before do
        expect(consolidator).to receive(:interpolate_manifest_for_deployment).with(deployment_name).and_return(interpolated_runtime_config)
      end

      it 'should return the tags hash' do
        expect(consolidator.tags(deployment_name)).to eq(runtime_config_tags)
      end

      context 'when there is NO tags key' do
        let(:interpolated_runtime_config) do
          {
            'releases' => [],
            'addons' => [],
          }
        end
        it 'should return an empty hash' do
          expect(consolidator.tags(deployment_name)).to eq({})
        end
      end
    end

    describe '#have_runtime_configs?' do
      it 'returns true when runtime configs exist' do
        expect(consolidator.have_runtime_configs?).to be_truthy
      end

      context 'when NO runtime configs exist' do
        let(:runtime_configs) { [] }

        it 'returns false' do
          expect(consolidator.have_runtime_configs?).to be_falsey
        end
      end
    end
  end
end
