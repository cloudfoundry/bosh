require 'spec_helper'

module Bosh::Director
  describe Manifest do
    subject(:manifest_object) { described_class.new(interpolated_manifest_hash, raw_manifest_hash, cloud_config_hash, runtime_config_hash) }
    let(:interpolated_manifest_hash) { {} }
    let(:raw_manifest_hash) { {} }
    let(:cloud_config_hash) { {} }
    let(:runtime_config_hash) { {} }

    before do
      release_1 = Models::Release.make(name: 'simple')
      Models::ReleaseVersion.make(version: 6, release: release_1)
      Models::ReleaseVersion.make(version: 9, release: release_1)

      release_1 = Models::Release.make(name: 'hard')
      Models::ReleaseVersion.make(version: '1+dev.5', release: release_1)
      Models::ReleaseVersion.make(version: '1+dev.7', release: release_1)

      Models::Stemcell.make(name: 'simple', version: '3163')
      Models::Stemcell.make(name: 'simple', version: '3169')

      Models::Stemcell.make(name: 'hard', version: '3146')
      Models::Stemcell.make(name: 'hard', version: '3146.1')
    end

    describe '.load_from_model' do
      let(:deployment_model) {instance_double(Bosh::Director::Models::Deployment)}
      let(:cloud_config) { Models::CloudConfig.make(manifest: {'name-2'=>'my-name-2'}) }
      let(:runtime_config) { Models::RuntimeConfig.make(manifest: {'name-3'=>'my-name-3'}) }

      before do
        allow(deployment_model).to receive(:manifest).and_return("{'name-1':'my-name-1'}")
        allow(deployment_model).to receive(:cloud_config).and_return(cloud_config)
        allow(deployment_model).to receive(:runtime_config).and_return(runtime_config)
      end

      it 'creates a manifest object from a manifest, a cloud config, and a runtime config' do
        result =  Manifest.load_from_model(deployment_model)
        expect(result.interpolated_manifest_hash).to eq({'name-1' => 'my-name-1'})
        expect(result.raw_manifest_hash).to eq({'name-1' => 'my-name-1'})
        expect(result.cloud_config_hash).to eq({'name-2' =>'my-name-2'})
        expect(result.runtime_config_hash).to eq({'name-3' =>'my-name-3'})
      end

      it 'ignores cloud config when ignore_cloud_config is true' do
        result = Manifest.load_from_model(deployment_model, {:ignore_cloud_config => true})
        expect(result.interpolated_manifest_hash).to eq({'name-1' => 'my-name-1'})
        expect(result.raw_manifest_hash).to eq({'name-1' => 'my-name-1'})
        expect(result.cloud_config_hash).to eq(nil)
        expect(result.runtime_config_hash).to eq({'name-3' =>'my-name-3'})
      end

      context 'when empty manifests exist' do
        let(:cloud_config) { Models::CloudConfig.make(manifest: nil) }
        let(:runtime_config) { Models::RuntimeConfig.make(manifest: nil) }

        before do
          allow(deployment_model).to receive(:manifest).and_return(nil)
        end

        it 'creates a manifest object from a manifest, a cloud config, and a runtime config correctly' do
          result =  Manifest.load_from_model(deployment_model)
          expect(result.interpolated_manifest_hash).to eq({})
          expect(result.raw_manifest_hash).to eq({})
          expect(result.cloud_config_hash).to eq(nil)
          expect(result.runtime_config_hash).to eq(nil)
        end
      end

      context 'when config server is around' do
        let(:cloud_config) { instance_double(Models::CloudConfig)}
        let(:runtime_config) { instance_double(Models::RuntimeConfig)}

        before do
          allow(cloud_config).to receive(:manifest).and_return({})
          allow(runtime_config).to receive(:manifest).and_return({})
          allow(deployment_model).to receive(:manifest).and_return("{'smurf': '((smurf_placeholder))'}")
          allow(deployment_model).to receive(:cloud_config).and_return(cloud_config)
          allow(deployment_model).to receive(:runtime_config).and_return(runtime_config)
        end


        context 'when it is disbaled' do
          before do
            allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
          end

          it 'load_from_model creates a manifest object from a cloud config, a manifest text, and a runtime config and does not resolve values' do
            expect(Bosh::Director::ConfigServer::ConfigParser).to_not receive(:parse)
            manifest_object_result = Manifest.load_from_model(deployment_model)
            expect(manifest_object_result.interpolated_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
            expect(manifest_object_result.raw_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
            expect(manifest_object_result.cloud_config_hash).to eq({})
            expect(manifest_object_result.runtime_config_hash).to eq({})
          end
        end

        context 'when it is enabled' do
          before do
            allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
          end

          it 'load_from_model creates a manifest object from a cloud config, a manifest text, and a runtime config and resolved values' do
            expect(Bosh::Director::ConfigServer::ConfigParser).to receive(:parse).with({'smurf' => '((smurf_placeholder))'}).and_return({'smurf' => 'blue'})
            manifest_object_result = Manifest.load_from_model(deployment_model)
            expect(manifest_object_result.interpolated_manifest_hash).to eq({'smurf' => 'blue'})
            expect(manifest_object_result.raw_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
            expect(manifest_object_result.cloud_config_hash).to eq({})
            expect(manifest_object_result.runtime_config_hash).to eq({})
          end

          it 'load_from_model does not resolve config server values if resolve_interpolation flag is false' do
            expect(Bosh::Director::ConfigServer::ConfigParser).to_not receive(:parse)
            manifest_object_result = Manifest.load_from_model(deployment_model, {:resolve_interpolation => false})
            expect(manifest_object_result.interpolated_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
            expect(manifest_object_result.raw_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
            expect(manifest_object_result.cloud_config_hash).to eq({})
            expect(manifest_object_result.runtime_config_hash).to eq({})
          end
        end
      end
    end

    describe '.load_from_hash' do
      let(:cloud_config) { Models::CloudConfig.make(manifest: {}) }
      let(:runtime_config) { Models::RuntimeConfig.make(manifest: {}) }

      it 'creates a manifest object from a cloud config, a manifest text, and a runtime config' do
        expect(
          Manifest.load_from_hash(interpolated_manifest_hash, cloud_config, runtime_config).to_yaml
        ).to eq(manifest_object.to_yaml)
      end

      it 'ignores cloud config when ignore_cloud_config is true' do
        result = Manifest.load_from_hash(interpolated_manifest_hash, cloud_config, runtime_config, {:ignore_cloud_config => true})
        expect(result.interpolated_manifest_hash).to eq({})
        expect(result.raw_manifest_hash).to eq({})
        expect(result.cloud_config_hash).to eq(nil)
        expect(result.runtime_config_hash).to eq({})
      end

      context 'when config server is around' do
        let(:passed_in_manifest_hash) { {'smurf' => '((smurf_placeholder))'} }
        let(:cloud_config) { instance_double(Models::CloudConfig)}
        let(:runtime_config) { instance_double(Models::RuntimeConfig)}

        before do
          allow(cloud_config).to receive(:manifest).and_return({})
          allow(runtime_config).to receive(:manifest).and_return({})
        end

        context 'when it is disbaled' do
          before do
            allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
          end

          it 'load_from_hash creates a manifest object from a cloud config, a manifest text, and a runtime config and does not resolve values' do
            expect(Bosh::Director::ConfigServer::ConfigParser).to_not receive(:parse)
            manifest_object_result = Manifest.load_from_hash(passed_in_manifest_hash, cloud_config, runtime_config)
            expect(manifest_object_result.interpolated_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
            expect(manifest_object_result.raw_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
            expect(manifest_object_result.cloud_config_hash).to eq({})
            expect(manifest_object_result.runtime_config_hash).to eq({})
          end
        end

        context 'when it is enabled' do
          before do
            allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
          end

          it 'load_from_hash creates a manifest object from a cloud config, a manifest text, and a runtime config and resolved values' do
            expect(Bosh::Director::ConfigServer::ConfigParser).to receive(:parse).with({'smurf' => '((smurf_placeholder))'}).and_return({'smurf' => 'blue'})
            manifest_object_result = Manifest.load_from_hash(passed_in_manifest_hash, cloud_config, runtime_config)
            expect(manifest_object_result.interpolated_manifest_hash).to eq({'smurf' => 'blue'})
            expect(manifest_object_result.raw_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
            expect(manifest_object_result.cloud_config_hash).to eq({})
            expect(manifest_object_result.runtime_config_hash).to eq({})
          end

          it 'load_from_hash does not resolve config server values if resolve_interpolation flag is false' do
            expect(Bosh::Director::ConfigServer::ConfigParser).to_not receive(:parse)
            manifest_object_result = Manifest.load_from_hash(passed_in_manifest_hash, cloud_config, runtime_config, {:resolve_interpolation => false})
            expect(manifest_object_result.interpolated_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
            expect(manifest_object_result.raw_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
            expect(manifest_object_result.cloud_config_hash).to eq({})
            expect(manifest_object_result.runtime_config_hash).to eq({})
          end
        end
      end
    end

    describe '.generate_empty_manifest' do
      it 'generates empty manifests' do
        result_manifest  = Manifest.generate_empty_manifest
        expect(result_manifest.interpolated_manifest_hash).to eq({})
        expect(result_manifest.raw_manifest_hash).to eq({})
        expect(result_manifest.cloud_config_hash).to eq(nil)
        expect(result_manifest.runtime_config_hash).to eq(nil)
      end

      it 'does not call config server parser even if config server is enabled' do
        allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
        expect(Bosh::Director::ConfigServer::ConfigParser).to_not receive(:parse)
        Manifest.generate_empty_manifest
      end
    end

    describe 'resolve_aliases' do
      context 'releases' do
        context 'when manifest has releases with version latest' do
          let(:interpolated_manifest_hash) do
            {
              'releases' => [
                {'name' => 'simple', 'version' => 'latest'},
                {'name' => 'hard', 'version' => 'latest'}
              ]
            }
          end

          it 'replaces latest with the latest version number' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['releases']).to eq([
              {'name' => 'simple', 'version' => '9'},
              {'name' => 'hard', 'version' => '1+dev.7'}
            ])
          end
        end

        context "when manifest has releases with version using '.latest' suffix" do
          let(:interpolated_manifest_hash) do
            {
              'releases' => [
                {'name' => 'simple', 'version' => '9.latest'},
                {'name' => 'hard', 'version' => '1.latest'}
              ]
            }
          end
          it 'should replace version with the relative latest' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['releases']).to eq([
              {'name' => 'simple', 'version' => '9'},
              {'name' => 'hard', 'version' => '1+dev.7'}
            ])
          end
        end

        context 'when manifest has no alias' do
          let(:interpolated_manifest_hash) do
            {
              'releases' => [
                {'name' => 'simple', 'version' => 9},
                {'name' => 'hard', 'version' => '42'}
              ]
            }
          end

          it 'leaves it as it is and converts to string' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['releases']).to eq([
             {'name' => 'simple', 'version' => '9'},
             {'name' => 'hard', 'version' => '42'}
            ])
          end
        end
      end

      context 'stemcells' do
        context 'when manifest has stemcells with version latest' do
          let(:interpolated_manifest_hash) do
            {
              'stemcells' => [
                {'name' => 'simple', 'version' => 'latest'},
                {'name' => 'hard', 'version' => 'latest'}
              ]
            }
          end

          it 'replaces latest with the latest version number' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['stemcells']).to eq([
              {'name' => 'simple', 'version' => '3169'},
              {'name' => 'hard', 'version' => '3146.1'}
            ])
          end
        end

        context 'when manifest has stemcell with version prefix' do
          let(:interpolated_manifest_hash) do
            {
              'stemcells' => [
                {'name' => 'simple', 'version' => '3169.latest'},
                {'name' => 'hard', 'version' => '3146.latest'},
              ]
            }
          end

          it 'replaces prefixed-latest with the latest version number' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['stemcells']).to eq([
              {'name' => 'simple', 'version' => '3169'},
              {'name' => 'hard', 'version' => '3146.1'},
            ])
          end
        end

        context 'when manifest has stemcell with no alias' do
          let(:interpolated_manifest_hash) do
            {
              'stemcells' => [
                {'name' => 'simple', 'version' => 42},
                {'name' => 'hard', 'version' => 'latest'}
              ]
            }
          end

          it 'leaves it as it is and converts to string' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['stemcells']).to eq([
              {'name' => 'simple', 'version' => '42'},
              {'name' => 'hard', 'version' => '3146.1'}
            ])
          end
        end

        context 'when cloud config has stemcells with version latest' do
          let(:cloud_config_hash) do
            {
              'resource_pools' => [
                {
                  'name' => 'rp1',
                  'stemcell' => { 'name' => 'simple', 'version' => 'latest'}
                }
              ]
            }
          end

          it 'replaces latest with the latest version number' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['resource_pools'].first['stemcell']).to eq(
              { 'name' => 'simple', 'version' => '3169'}
            )
          end
        end

        context 'when cloud config has stemcells with version prefix' do
          let(:cloud_config_hash) do
            {
              'resource_pools' => [
                {
                  'name' => 'rp1',
                  'stemcell' => { 'name' => 'simple', 'version' => '3169.latest'}
                }
              ]
            }
          end

          it 'replaces the correct version match' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['resource_pools'].first['stemcell']).to eq(
              { 'name' => 'simple', 'version' => '3169'}
            )
          end
        end
      end
    end

    describe '#diff' do
      subject(:new_manifest_object) { described_class.new(new_interpolated_manifest_hash, new_raw_manifest_hash, new_cloud_config_hash, new_runtime_config_hash) }
      let(:new_interpolated_manifest_hash) do
        {
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
      let(:new_raw_manifest_hash) { raw_manifest_hash }
      let(:new_cloud_config_hash) { cloud_config_hash }
      let(:new_runtime_config_hash) { runtime_config_hash }
      let(:diff) do
        manifest_object.diff(new_manifest_object, redact).map(&:text).join("\n")
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
      context 'when runtime config contains same release/version as deployment manifest' do
        let(:interpolated_manifest_hash) do
          {
              'releases' => [
                  {'name' => 'simple', 'version' => '2'},
                  {'name' => 'hard', 'version' => 'latest'}
              ]
          }
        end

        let(:runtime_config_hash) do
          {
              'releases' => [
                  {'name' => 'simple', 'version' => '2'}
              ]
          }
        end

        it 'includes only one copy of the release in to_hash output' do
          expect(manifest_object.to_hash['releases']).to eq([
               {'name' => 'simple', 'version' => '2'},
               {'name' => 'hard', 'version' => 'latest'}
           ])
        end
      end
    end
  end
end
