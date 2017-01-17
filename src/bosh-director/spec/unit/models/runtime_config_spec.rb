require 'spec_helper'

module Bosh::Director::Models
  describe RuntimeConfig do
    let(:runtime_config_model) { RuntimeConfig.make(raw_manifest: mock_manifest) }
    let(:mock_manifest) { {name: '((manifest_name))'} }
    let(:new_runtime_config) { {name: 'runtime manifest'} }
    let(:deployment_name) { 'some_deployment_name' }

    describe "#interpolated_manifest_for_deployment" do
      let(:client_factory) { instance_double(Bosh::Director::ConfigServer::ClientFactory) }
      let(:config_server_client) { instance_double(Bosh::Director::ConfigServer::EnabledClient) }
      let(:logger) { instance_double(Logging::Logger) }

      before do
        allow(Bosh::Director::Config).to receive(:logger).and_return(logger)
        allow(Bosh::Director::ConfigServer::ClientFactory).to receive(:create).with(logger).and_return(client_factory)
        allow(client_factory).to receive(:create_client).and_return(config_server_client)
        allow(config_server_client).to receive(:interpolate_runtime_manifest).with(mock_manifest, deployment_name).and_return(new_runtime_config)
      end

      it 'calls manifest resolver and returns its result' do
        result = runtime_config_model.interpolated_manifest_for_deployment(deployment_name)
        expect(result).to eq(new_runtime_config)
      end
    end

    describe "#raw_manifest" do
      it 'returns raw result' do
        expect(runtime_config_model.raw_manifest).to eq(mock_manifest)
      end
    end

    describe '#tags' do
      context 'when there are no tags' do
        it 'returns an empty hash' do
          expect(runtime_config_model.tags(deployment_name)).to eq({})
        end
      end

      context 'when there are tags' do
        let(:mock_manifest) { {'tags' => {'my-tag' => 'best-value'}}}
        let(:uninterpolated_mock_manifest) { {'tags' => {'my-tag' => '((a_value))'}} }

        it 'returns interpolated values from the manifest' do
          allow(runtime_config_model).to receive(:interpolated_manifest_for_deployment).with(deployment_name).and_return({'tags' => {'my-tag' => 'something'}})
          expect(runtime_config_model.tags(deployment_name)).to eq({'my-tag' => 'something'})
        end

        it 'returns the tags from the manifest' do
          expect(runtime_config_model.tags(deployment_name)).to eq({'my-tag' => 'best-value'})
        end
      end
    end
  end
end