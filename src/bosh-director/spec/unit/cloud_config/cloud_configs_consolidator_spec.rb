require 'spec_helper'

module Bosh::Director
  describe CloudConfig::CloudConfigsConsolidator do
    subject(:consolidator) { described_class.new(cloud_configs) }
    let(:cc_model_1) do
      FactoryBot.create(:models_config, id: 1, content: cloud_config_1.to_yaml, raw_manifest: cloud_config_1)
    end
    let(:cc_model_2) do
      FactoryBot.create(:models_config, id: 21, content: cloud_config_2.to_yaml, raw_manifest: cloud_config_2)
    end
    let(:cc_model_3) do
      FactoryBot.create(:models_config, id: 65, content: cloud_config_3.to_yaml, raw_manifest: cloud_config_3)
    end
    let(:cloud_configs) { [cc_model_1, cc_model_2, cc_model_3] }
    let(:cloud_config_1) do
      {
        'azs' => [az_1],
        'vm_types' => [vm_typ_1],
        'disk_types' => [disk_type_1],
        'networks' => [network_1],
      }
    end

    let(:cloud_config_2) do
      {
        'azs' => [az_2],
        'vm_types' => [vm_type_2],
        'networks' => [network_2],
        'vm_extensions' => [vm_extension_1],
      }
    end

    let(:cloud_config_3) do
      {
        'compilation' => compilation,
        'disk_types' => [disk_type_2],
        'vm_extensions' => [vm_extension_2],
      }
    end
    let(:az_1) do
      { 'name' => 'z1' }
    end

    let(:az_2) do
      { 'name' => 'z2' }
    end

    let(:vm_typ_1) do
      { 'name' => 'small' }
    end

    let(:vm_type_2) do
      { 'name' => 'medium' }
    end

    let(:disk_type_1) do
      { 'disk_size' => 3_000 }
    end

    let(:disk_type_2) do
      { 'disk_size' => 50_000 }
    end

    let(:network_1) do
      { 'name' => 'private' }
    end

    let(:network_2) do
      { 'type' => 'vip', 'name' => 'vip' }
    end

    let(:compilation) do
      { 'workers' => 5 }
    end

    let(:vm_extension_1) do
      { 'name' => 'pub-lbs' }
    end

    let(:vm_extension_2) do
      { 'name' => 'pub-lbs2' }
    end

    describe '#create_from_model_ids' do
      it 'calls initialize with the models' do
        expect(Bosh::Director::CloudConfig::CloudConfigsConsolidator).to receive(:new).with([cc_model_1, cc_model_2])
        Bosh::Director::CloudConfig::CloudConfigsConsolidator.create_from_model_ids([1, 21, 65])
      end
    end

    describe '#raw_manifest' do
      let(:consolidated_manifest) do
        {
          'azs' => [
            az_1,
            az_2,
          ],
          'vm_types' => [
            vm_typ_1,
            vm_type_2,
          ],
          'disk_types' => [
            disk_type_1,
            disk_type_2,
          ],
          'networks' => [
            network_1,
            network_2,
          ],
          'compilation' => compilation,
          'vm_extensions' => [
            vm_extension_1,
            vm_extension_2,
          ],
        }
      end

      it 'returns a consolidated manifest consisting of the specified configs manifests' do
        expect(consolidator.raw_manifest).to eq(consolidated_manifest)
      end

      context 'when there are top-level variables' do
        before do
          cloud_config_1['disk_types'] = '((disk_type_variable))'
          consolidated_manifest['disk_types'] = ['((disk_type_variable))', disk_type_2]
        end
        it 'merges top-level variables with arrays of other configs' do
          expect(consolidator.raw_manifest).to eq(consolidated_manifest)
        end
      end

      context 'when there are no models' do
        let(:cloud_configs) { [] }

        it 'returns an empty hash' do
          expect(consolidator.raw_manifest).to eq({})
        end
      end

      context 'with an empty cloud config (previously supported before generic configs)' do
        let(:cloud_config_1) do
          { 'networks' => ['fooba'] }
        end
        let(:cloud_config_2) { nil }
        let(:cloud_config_3) { nil }

        it 'assumes an empty hash for that manifest' do
          result = consolidator.raw_manifest
          expect(result).to eq({"azs"=>[], "vm_types"=>[], "disk_types"=>[], "networks"=>["fooba"], "vm_extensions"=>[]})
        end
      end


      context 'when a given key is not an array' do
        ['azs', 'vm_types', 'disk_types', 'networks', 'vm_extensions'].each do |key|
          context "when #{key} is not an array" do
            let(:cloud_config_1) do
              {
                key => 'omg',
              }
            end

            it 'returns an error' do
              expect {
                consolidator.raw_manifest
              }.to raise_error(Bosh::Director::ValidationInvalidType,
                               /Property '#{key}' value \("omg"\) did not match the required type 'Array'/)
            end
          end
        end
      end

      context 'when more than one cloud config defines the compilation key' do
        let(:cloud_config_2) do
          {
            'compilation' => { 'foo' => 'bar' },
          }
        end

        let(:cloud_config_3) do
          {
            'compilation' => { 'moop' => 'yarb' },
          }
        end

        it 'returns an error' do
          expect {
            consolidator.raw_manifest
          }.to raise_error CloudConfigMergeError, "Cloud config 'compilation' key cannot be defined in multiple cloud configs."
        end
      end

    end

    describe '#interpolate_manifest_for_deployment' do
      let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }
      let(:mock_manifest) do
        { name: '((manifest_name))' }
      end
      let(:deployment_name) { 'some_deployment_name' }
      let(:interpolated_cloud_config) do
        { name: 'interpolated manifest' }
      end

      before do
        allow(Bosh::Director::ConfigServer::VariablesInterpolator).to receive(:new).and_return(variables_interpolator)
        allow(variables_interpolator).to receive(:interpolate_cloud_manifest).with(mock_manifest, deployment_name).and_return(interpolated_cloud_config)
        allow(consolidator).to receive(:raw_manifest).and_return(mock_manifest)
      end

      it 'calls manifest resolver and returns its result' do
        result = consolidator.interpolate_manifest_for_deployment(deployment_name)
        expect(result).to eq(interpolated_cloud_config)
      end

      context 'with variable being an array at top-level' do
        let(:mock_manifest) do
          { disk_types: '((disk_type_array))' }
        end
        let(:interpolated_cloud_config) do
          {
            disk_types: [
              [{
                'name' => 'small',
                'cloud_properties' => { 'type' => 'gp2' },
              }],
            ],
          }
        end
        let(:flattened_interpolated_cloud_config) do
          {
            disk_types: [{
              'name' => 'small',
              'cloud_properties' => { 'type' => 'gp2' },
            }],
          }
        end

        it 'flattens any top-level nested array' do
          result = consolidator.interpolate_manifest_for_deployment(deployment_name)
          expect(result).to eq(flattened_interpolated_cloud_config)
        end
      end
    end

    describe '#have_cloud_configs?' do
      it 'returns true when cloud configs exist' do
        expect(described_class.have_cloud_configs?(cloud_configs)).to be_truthy
      end

      context 'when NO cloud configs exist' do
        let(:cloud_configs) { [] }

        it 'returns false' do
          expect(described_class.have_cloud_configs?(cloud_configs)).to be_falsy
        end
      end

      context 'when cloud configs are empty' do
        let(:cloud_configs) { [FactoryBot.create(:models_config)] }

        it 'returns false' do
          expect(described_class.have_cloud_configs?(cloud_configs)).to be_falsy
        end
      end
    end
  end
end
