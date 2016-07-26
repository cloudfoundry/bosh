require 'spec_helper'

module Bosh::Director::Models
  describe RuntimeConfig do
    let(:runtime_config_model) { RuntimeConfig.make(manifest: mock_manifest) }
    let(:mock_manifest) { { name: '((manifest_name))' } }
    let(:new_runtime_config) { { name: 'runtime manifest' } }

    describe "#manifest" do
      it 'calls manifest resolver and returns its result' do
        allow(Bosh::Director::RuntimeConfig::RuntimeManifestResolver).to receive(:resolve_manifest).with(mock_manifest).and_return(new_runtime_config)
        expect(runtime_config_model.manifest).to eq(new_runtime_config)
      end
    end

    describe "#raw_manifest" do
      it 'returns raw result' do
        expect(runtime_config_model.raw_manifest).to eq(mock_manifest)
      end
    end
  end
end
