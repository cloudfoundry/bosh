require 'spec_helper'

module Bosh::Director
  describe Manifest do
    subject(:manifest_object) do
      described_class.new(hybrid_manifest_hash, raw_manifest_hash, cloud_config_hash, hybrid_runtime_config_hash, raw_runtime_config_hash)
    end
    let(:hybrid_manifest_hash) { {} }
    let(:raw_manifest_hash) { {} }
    let(:cloud_config_hash) { {} }
    let(:hybrid_runtime_config_hash) { {} }
    let(:raw_runtime_config_hash) { {} }

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
        expect(result.hybrid_manifest_hash).to eq({'name-1' => 'my-name-1'})
        expect(result.raw_manifest_hash).to eq({'name-1' => 'my-name-1'})
        expect(result.cloud_config_hash).to eq({'name-2' =>'my-name-2'})
        expect(result.hybrid_runtime_config_hash).to eq({'name-3' =>'my-name-3'})
      end

      it 'ignores cloud config when ignore_cloud_config is true' do
        result = Manifest.load_from_model(deployment_model, {:ignore_cloud_config => true})
        expect(result.hybrid_manifest_hash).to eq({'name-1' => 'my-name-1'})
        expect(result.raw_manifest_hash).to eq({'name-1' => 'my-name-1'})
        expect(result.cloud_config_hash).to eq(nil)
        expect(result.hybrid_runtime_config_hash).to eq({'name-3' =>'my-name-3'})
      end

      context 'when empty manifests exist' do
        let(:cloud_config) { Models::CloudConfig.make(manifest: nil) }
        let(:runtime_config) { Models::RuntimeConfig.make(manifest: nil) }

        before do
          allow(deployment_model).to receive(:manifest).and_return(nil)
        end

        it 'creates a manifest object from a manifest, a cloud config, and a runtime config correctly' do
          result =  Manifest.load_from_model(deployment_model)
          expect(result.hybrid_manifest_hash).to eq({})
          expect(result.raw_manifest_hash).to eq({})
          expect(result.cloud_config_hash).to eq(nil)
          expect(result.hybrid_runtime_config_hash).to eq(nil)
        end
      end

      context 'when resolving manifest' do
        let(:cloud_config) { instance_double(Models::CloudConfig)}
        let(:runtime_config) { instance_double(Models::RuntimeConfig)}
        let(:client_factory) { instance_double(Bosh::Director::ConfigServer::ClientFactory)}
        let(:config_server_client) { instance_double(Bosh::Director::ConfigServer::EnabledClient)}
        let(:logger) { instance_double(Logging::Logger)}

        before do
          allow(cloud_config).to receive(:manifest).and_return({})
          allow(runtime_config).to receive(:manifest).and_return({})
          allow(runtime_config).to receive(:raw_manifest).and_return({})
          allow(deployment_model).to receive(:manifest).and_return("{'smurf': '((smurf_placeholder))'}")
          allow(deployment_model).to receive(:cloud_config).and_return(cloud_config)
          allow(deployment_model).to receive(:runtime_config).and_return(runtime_config)
          allow(Bosh::Director::Config).to receive(:logger).and_return(logger)
          allow(Bosh::Director::ConfigServer::ClientFactory).to receive(:create).with(logger).and_return(client_factory)
          allow(client_factory).to receive(:create_client).and_return(config_server_client)
        end

        it 'calls the manifest resolver with correct values' do
          expect(config_server_client).to receive(:interpolate_deployment_manifest).with({'smurf' => '((smurf_placeholder))'}).and_return({'smurf' => 'blue'})
          manifest_object_result = Manifest.load_from_model(deployment_model)
          expect(manifest_object_result.hybrid_manifest_hash).to eq({'smurf' => 'blue'})
          expect(manifest_object_result.raw_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
          expect(manifest_object_result.cloud_config_hash).to eq({})
          expect(manifest_object_result.hybrid_runtime_config_hash).to eq({})

        end

        it 'respects resolve_interpolation flag when calling the manifest resolver' do
          manifest_object_result = Manifest.load_from_model(deployment_model, {:resolve_interpolation => false})
          expect(config_server_client).to_not receive(:interpolate_deployment_manifest)
          expect(manifest_object_result.hybrid_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
          expect(manifest_object_result.raw_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
          expect(manifest_object_result.cloud_config_hash).to eq({})
          expect(manifest_object_result.hybrid_runtime_config_hash).to eq({})
        end
      end
    end

    describe '.load_from_hash' do
      let(:cloud_config) { Models::CloudConfig.make(manifest: {}) }
      let(:runtime_config) { Models::RuntimeConfig.make(manifest: {}) }

      it 'creates a manifest object from a cloud config, a manifest text, and a runtime config' do
        expect(
          Manifest.load_from_hash(hybrid_manifest_hash, cloud_config, runtime_config).to_yaml
        ).to eq(manifest_object.to_yaml)
      end

      it 'ignores cloud config when ignore_cloud_config is true' do
        result = Manifest.load_from_hash(hybrid_manifest_hash, cloud_config, runtime_config, {:ignore_cloud_config => true})
        expect(result.hybrid_manifest_hash).to eq({})
        expect(result.raw_manifest_hash).to eq({})
        expect(result.cloud_config_hash).to eq(nil)
        expect(result.hybrid_runtime_config_hash).to eq({})
      end

      context 'when resolving manifest' do
        let(:passed_in_manifest_hash) { {'smurf' => '((smurf_placeholder))'} }
        let(:cloud_config) { instance_double(Models::CloudConfig)}
        let(:runtime_config) { instance_double(Models::RuntimeConfig)}
        let(:client_factory) { instance_double(Bosh::Director::ConfigServer::ClientFactory)}
        let(:config_server_client) { instance_double(Bosh::Director::ConfigServer::EnabledClient)}
        let(:logger) { instance_double(Logging::Logger)}

        before do
          allow(cloud_config).to receive(:manifest).and_return({})
          allow(runtime_config).to receive(:manifest).and_return({})
          allow(runtime_config).to receive(:raw_manifest).and_return({})
          allow(Bosh::Director::Config).to receive(:logger).and_return(logger)
          allow(Bosh::Director::ConfigServer::ClientFactory).to receive(:create).with(logger).and_return(client_factory)
          allow(client_factory).to receive(:create_client).and_return(config_server_client)
        end

        it 'calls the manifest resolver with correct values' do
          expect(config_server_client).to receive(:interpolate_deployment_manifest).with({'smurf' => '((smurf_placeholder))'}).and_return({'smurf' => 'blue'})
          manifest_object_result = Manifest.load_from_hash(passed_in_manifest_hash, cloud_config, runtime_config)
          expect(manifest_object_result.hybrid_manifest_hash).to eq({'smurf' => 'blue'})
          expect(manifest_object_result.raw_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
          expect(manifest_object_result.cloud_config_hash).to eq({})
          expect(manifest_object_result.hybrid_runtime_config_hash).to eq({})
        end

        it 'respects resolve_interpolation flag when calling the manifest resolver' do
          expect(config_server_client).to_not receive(:interpolate_deployment_manifest)

          manifest_object_result = Manifest.load_from_hash(passed_in_manifest_hash, cloud_config, runtime_config, {:resolve_interpolation => false})
          expect(manifest_object_result.hybrid_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
          expect(manifest_object_result.raw_manifest_hash).to eq({'smurf' => '((smurf_placeholder))'})
          expect(manifest_object_result.cloud_config_hash).to eq({})
          expect(manifest_object_result.hybrid_runtime_config_hash).to eq({})
        end
      end
    end

    describe '.generate_empty_manifest' do
      it 'generates empty manifests' do
        result_manifest  = Manifest.generate_empty_manifest
        expect(result_manifest.hybrid_manifest_hash).to eq({})
        expect(result_manifest.raw_manifest_hash).to eq({})
        expect(result_manifest.cloud_config_hash).to eq(nil)
        expect(result_manifest.hybrid_runtime_config_hash).to eq(nil)
      end

      it 'does not call config server client even if config server is enabled' do
        allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
        expect(Bosh::Director::ConfigServer::EnabledClient).to_not receive(:interpolate)
        Manifest.generate_empty_manifest
      end
    end

    describe 'resolve_aliases' do
      context 'releases' do
        context 'when manifest has releases with version latest' do
          let(:provided_hash) do
            {
              'releases' => [
                {'name' => 'simple', 'version' => 'latest'},
                {'name' => 'hard', 'version' => 'latest'}
              ]
            }
          end

          let(:hybrid_manifest_hash) {provided_hash}
          let(:raw_manifest_hash) {provided_hash}

          it 'replaces latest with the latest version number' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['releases']).to eq([
              {'name' => 'simple', 'version' => '9'},
              {'name' => 'hard', 'version' => '1+dev.7'}
            ])
            expect(manifest_object.raw_manifest_hash['releases']).to eq([
              {'name' => 'simple', 'version' => '9'},
              {'name' => 'hard', 'version' => '1+dev.7'}
            ])
          end
        end

        context "when manifest has releases with version using '.latest' suffix" do
          let(:provided_hash) do
            {
              'releases' => [
                {'name' => 'simple', 'version' => '9.latest'},
                {'name' => 'hard', 'version' => '1.latest'}
              ]
            }
          end

          let(:hybrid_manifest_hash) {provided_hash}
          let(:raw_manifest_hash) {provided_hash}

          it 'should replace version with the relative latest' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['releases']).to eq([
              {'name' => 'simple', 'version' => '9'},
              {'name' => 'hard', 'version' => '1+dev.7'}
            ])
            expect(manifest_object.raw_manifest_hash['releases']).to eq([
              {'name' => 'simple', 'version' => '9'},
              {'name' => 'hard', 'version' => '1+dev.7'}
            ])
          end
        end

        context 'when manifest has no alias' do
          let(:provided_hash) do
            {
              'releases' => [
                {'name' => 'simple', 'version' => 9},
                {'name' => 'hard', 'version' => '42'}
              ]
            }
          end

          let(:hybrid_manifest_hash) {provided_hash}
          let(:raw_manifest_hash) {provided_hash}

          it 'leaves it as it is and converts to string' do
            manifest_object.resolve_aliases
            expect(manifest_object.to_hash['releases']).to eq([
             {'name' => 'simple', 'version' => '9'},
             {'name' => 'hard', 'version' => '42'}
            ])
            expect(manifest_object.raw_manifest_hash['releases']).to eq([
             {'name' => 'simple', 'version' => '9'},
             {'name' => 'hard', 'version' => '42'}
            ])
          end
        end
      end

      context 'stemcells' do
        context 'when manifest has stemcells with version latest' do
          let(:hybrid_manifest_hash) do
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
          let(:hybrid_manifest_hash) do
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
          let(:hybrid_manifest_hash) do
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
      subject(:new_manifest_object) do
        described_class.new(
          new_hybrid_manifest_hash,
          new_raw_manifest_hash,
          new_cloud_config_hash,
          new_hybrid_runtime_config_hash,
          new_raw_runtime_config_hash
        )
      end

      let(:new_raw_manifest_hash) do
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

      let(:new_hybrid_manifest_hash) { hybrid_manifest_hash }
      let(:new_cloud_config_hash) { cloud_config_hash }
      let(:new_hybrid_runtime_config_hash) { hybrid_runtime_config_hash }
      let(:new_raw_runtime_config_hash) { raw_runtime_config_hash }
      let(:diff) do
        manifest_object.diff(new_manifest_object, redact).map(&:text).join("\n")
      end

      context 'when called' do
        let(:redact) { true }
        let(:mock_changeset) {instance_double(Bosh::Director::Changeset)}
        let(:diff_return) { double( order: '') }

        it 'calls changeset with correct parameters' do
          expect(Bosh::Director::Changeset).to receive(:new).and_return(mock_changeset)
          expect(mock_changeset).to receive(:diff).with(true).and_return(diff_return)
          expect(diff_return).to receive(:order)
          expect(manifest_object).to receive(:to_hash).with({:raw => true}).and_return({})
          expect(new_manifest_object).to receive(:to_hash).with({:raw => true}).and_return({})
          manifest_object.diff(new_manifest_object, redact)
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

      let(:raw_manifest_hash) do
        {
          'releases' => [
            {'name' => 'simple', 'version' => '2'}
          ],
          'properties' => {
            'test' => '((test_placeholder))'
          }
        }
      end

      let(:hybrid_manifest_hash) do
        {
          'releases' => [
            {'name' => 'simple', 'version' => '2'}
          ],
          'properties' => {
            'test' => 'helo'
          }
        }
      end

      let(:raw_runtime_config_hash) do
        {
          'releases' => [
            {'name' => 'runtime_release', 'version' => '2'}
          ],
          'addons' => [
            {
              'name' => 'test',
              'properties' => {
                'test2' => '((test2_placeholder))'
              }
            }
          ]
        }
      end

      let(:hybrid_runtime_config_hash) do
        {
          'releases' => [
            {'name' => 'runtime_release', 'version' => '2'}
          ],
          'addons' => [
            {
              'name' => 'test',
              'properties' => {
                'test2' => 'smurfy'
              }
            }
          ]
        }
      end

      it 'returns interpolated hash by default' do
        expect(manifest_object.to_hash).to eq({
          'releases' => [
            {'name' => 'simple', 'version' => '2'},
            {'name' => 'runtime_release', 'version' => '2'}
          ],
          'addons' => [
            {
              'name' => 'test',
              'properties' => {
                'test2' => 'smurfy',
              }
            }
          ],
          'properties' => {
            'test' => 'helo'
          }
        })
      end

      it 'returns raw hash output when raw=true flag is passed in' do
        expect(manifest_object.to_hash({:raw => true})).to eq({
          'releases' => [
            {'name' => 'simple', 'version' => '2'},
            {'name' => 'runtime_release', 'version' => '2'}
          ],
          'addons' => [
            {
              'name' => 'test',
              'properties' => {
                'test2' => '((test2_placeholder))',
              }
            }
          ],
          'properties' => {
            'test' => '((test_placeholder))'
          }
        })
      end
      
      context 'when runtime config contains same release/version as deployment manifest' do
        let(:hybrid_manifest_hash) do
          {
              'releases' => [
                  {'name' => 'simple', 'version' => '2'},
                  {'name' => 'hard', 'version' => 'latest'}
              ]
          }
        end

        let(:hybrid_runtime_config_hash) do
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
