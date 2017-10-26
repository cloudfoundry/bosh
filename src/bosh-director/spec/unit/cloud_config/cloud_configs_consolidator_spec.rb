require 'spec_helper'

module Bosh::Director
  describe CloudConfig::CloudConfigsConsolidator do
    subject(:consolidator) { described_class.new(cloud_configs) }
    let(:cc_model_1) { instance_double(Bosh::Director::Models::Config)}
    let(:cc_model_2) { instance_double(Bosh::Director::Models::Config)}
    let(:cc_model_3) { instance_double(Bosh::Director::Models::Config)}
    let(:cloud_configs) { [ cc_model_1, cc_model_2, cc_model_3] }

    describe '#create_from_model_ids' do
      let(:cloud_configs) { [
        instance_double(Bosh::Director::Models::Config),
        instance_double(Bosh::Director::Models::Config),
      ]}

      let(:cloud_config_ids) {
        [1,21,65]
      }
      before do
        allow(Bosh::Director::Models::Config).to receive(:find_by_ids).with(cloud_config_ids).and_return(cloud_configs)
      end

      it 'calls initialize with the models' do
        expect(Bosh::Director::CloudConfig::CloudConfigsConsolidator).to receive(:new).with(cloud_configs)
        Bosh::Director::CloudConfig::CloudConfigsConsolidator.create_from_model_ids(cloud_config_ids)
      end
    end

    describe '#raw_manifest' do
      before do
        allow(cc_model_1).to receive(:raw_manifest).and_return(cloud_config_1)
        allow(cc_model_2).to receive(:raw_manifest).and_return(cloud_config_2)
        allow(cc_model_3).to receive(:raw_manifest).and_return(cloud_config_3)
      end

      let(:az_1) {
        {
          'name' => 'z1',
          'cloud_properties' => {
            'availability_zone' => 'us-east-1a'
          }
        }
      }

      let(:az_2) {
        {
          'name' => 'z2',
          'cloud_properties' => {
            'availability_zone' => 'us-east-1b'
          }
        }
      }

      let(:vm_typ_1) {
        {
          'name' => 'small',
          'cloud_properties' => {
            'instance_type' => 't2.micro',
            'ephemeral_disk' => {
              'type' => 'gp2',
              'size' => 3000
            }
          }
        }
      }

      let(:vm_type_2) {
        {
          'name' => 'medium',
          'cloud_properties' => {
            'instance_type' => 'm3.medium',
            'ephemeral_disk' => {
              'type' => 'gp2',
              'size' => 30000
            }
          }
        }
      }

      let(:disk_type_1) {
        {
          'disk_size' => 3000,
          'name' => 'small',
          'cloud_properties' => {
            'type' => 'gp2'
          }
        }
      }

      let(:disk_type_2) {
        {
          'disk_size' => 50000,
          'name' => 'large',
          'cloud_properties' => {
            'type' => 'gp2'
          }
        }
      }

      let(:network_1) {
        {
          'subnets' => [
            {
              'range' => '10.10.0.0/24',
              'static' => [
                '10.10.0.62'
              ],
              'dns' => [
                '10.10.0.2'
              ],
              'az' => 'z1',
              'cloud_properties' => {
                'subnet' => 'subnet-f2744a86'
              },
              'gateway' => '10.10.0.1'
            },
            {
              'range' => '10.10.64.0/24',
              'static' => [ '10.10.64.121', '10.10.64.122' ],
              'dns' => [
                '10.10.0.2'
              ],
              'az' => 'z2',
              'cloud_properties' => {
                'subnet'=> 'subnet-eb8bd3ad'
              },
              'gateway' => '10.10.64.1'
            }
          ],
          'type' => 'manual',
          'name' => 'private'
        }
      }

      let(:network_2) {
        {
          'type' => 'vip',
          'name' => 'vip'
        }
      }

      let(:compilation) {
        {
          'workers' => 5,
          'az' => 'z1',
          'vm_type' => 'medium',
          'reuse_compilation_vms' => true,
          'network' => 'private'
        }
      }

      let(:vm_extension_1) {
        {
          'name' => 'pub-lbs',
          'cloud_properties' => {
            'elbs' => ['main']
          }
        }
      }

     let(:vm_extension_2) {
        {
          'name' => 'pub-lbs2',
          'cloud_properties' => {
            'elbs2' => ['main2']
          }
        }
     }

      let(:cloud_config_1) {
        {
          'azs' => [
            az_1
          ],
          'vm_types' => [
            vm_typ_1
          ],
          'disk_types' => [
            disk_type_1
          ],
          'networks' => [
            network_1
          ]
        }
      }

      let(:cloud_config_2) {
        {
          'azs' => [
            az_2
          ],
          'vm_types' => [
            vm_type_2
          ],
          'networks' => [
            network_2
          ],
          'vm_extensions' => [
            vm_extension_1
          ]
        }
      }

      let(:cloud_config_3) {
        {
          'compilation' => compilation,
          'disk_types' => [
            disk_type_2
          ],
          'vm_extensions' => [
            vm_extension_2
          ]
        }
      }

      let(:consolidated_manifest) {
        {
          'azs' => [
            az_1,
            az_2
          ],
          'vm_types' => [
            vm_typ_1,
            vm_type_2
          ],
          'disk_types' => [
            disk_type_1,
            disk_type_2
          ],
          'networks' => [
            network_1,
            network_2
          ],
          'compilation' => compilation,
          'vm_extensions' => [
            vm_extension_1,
            vm_extension_2,
          ]
        }
      }

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
              }.to raise_error
            end
          end
        end
      end

      context 'when more than one cloud config defines the compilation key' do
        let(:cloud_config_2) {
          {
              'compilation' => {'foo' => 'bar'}
          }
        }

        let(:cloud_config_3) {
          {
              'compilation' => {'moop' => 'yarb'}
          }
        }

        it 'returns an error' do
          expect {
            consolidator.raw_manifest
          }.to raise_error CloudConfigMergeError, "Cloud config 'compilation' key cannot be defined in multiple cloud configs."
        end
      end

    end

    describe '#interpolate_manifest_for_deployment' do
      let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }
      let(:mock_manifest) { {name: '((manifest_name))'} }
      let(:deployment_name) { 'some_deployment_name' }
      let(:interpolated_cloud_config) { {name: 'interpolated manifest'} }

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
        let(:mock_manifest) { {disk_types: '((disk_type_array))'} }
        let(:interpolated_cloud_config) { {disk_types: [[{
          'name' => 'small',
          'cloud_properties' => {'type' => 'gp2'}
        }]]} }
        let(:flattened_interpolated_cloud_config) { {disk_types: [{
          'name' => 'small',
          'cloud_properties' => {'type' => 'gp2'}
        }]} }

        it 'flattens any top-level nested array' do
          result = consolidator.interpolate_manifest_for_deployment(deployment_name)
          expect(result).to eq(flattened_interpolated_cloud_config)
        end
      end
    end

    describe '#have_cloud_configs?' do
      it 'returns true when cloud configs exist' do
        expect(consolidator.have_cloud_configs?).to be_truthy
      end

      context 'when NO cloud configs exist' do
        let(:cloud_configs) { [] }

        it 'returns false' do
          expect(consolidator.have_cloud_configs?).to be_falsy
        end
      end
    end
  end
end
