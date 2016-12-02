require 'spec_helper'

module Bosh::Director::Models
  describe RuntimeConfig do
    let(:runtime_config_model) { RuntimeConfig.make(manifest: mock_manifest) }
    let(:mock_manifest) { {name: '((manifest_name))'} }
    let(:new_runtime_config) { {name: 'runtime manifest'} }

    describe "#manifest" do
      let(:client_factory) { instance_double(Bosh::Director::ConfigServer::ClientFactory) }
      let(:config_server_client) { instance_double(Bosh::Director::ConfigServer::EnabledClient) }
      let(:logger) { instance_double(Logging::Logger) }

      before do
        allow(Bosh::Director::Config).to receive(:logger).and_return(logger)
        allow(Bosh::Director::ConfigServer::ClientFactory).to receive(:create).with(logger).and_return(client_factory)
        allow(client_factory).to receive(:create_client).and_return(config_server_client)
        allow(config_server_client).to receive(:interpolate_runtime_manifest).with(mock_manifest).and_return(new_runtime_config)
      end

      it 'calls manifest resolver and returns its result' do
        expect(runtime_config_model.manifest).to eq(new_runtime_config)
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
          expect(runtime_config_model.tags).to eq({})
        end
      end

      context 'when there are tags' do
        let(:mock_manifest) { {'tags' => {'my-tag' => 'best-value'}} }

        it 'returns the tags from the manifest' do
          expect(runtime_config_model.tags).to eq({'my-tag' => 'best-value'})
        end
      end
    end
  end
end
