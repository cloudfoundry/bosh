require 'spec_helper'

module Bosh::Director::Models
  describe RuntimeConfig do
    let(:mock_manifest) { { name: '((manifest_name))' } }
    let(:runtime_config) { RuntimeConfig.make(manifest: mock_manifest) }
    let(:new_runtime_config) { { name: 'runtime manifest' } }

    describe "#manifest" do

      before do
        dbl = instance_double("Bosh::Director::ConfigServer::ConfigParser", parsed: new_runtime_config)
        allow(Bosh::Director::ConfigServer::ConfigParser).to receive(:new).and_return(dbl)
      end

      context "when config server is used" do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
        end

        it "returns runtime config with placeholders replaced" do
          expect(runtime_config.manifest).to eq(new_runtime_config)
        end
      end

      context "when config server is not used" do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
        end

        it "returns manifest without replacing the placeholders" do
          expect(runtime_config.manifest).to eq(mock_manifest)
        end
      end
    end
  end
end