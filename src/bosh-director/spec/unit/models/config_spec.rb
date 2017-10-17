require 'spec_helper'

module Bosh::Director::Models
  describe Config do
    let(:config_model) { Config.make(content: "---\n{key : value}") }

    describe '#raw_manifest' do
      it 'returns raw content as parsed yaml' do
        expect(config_model.name).to eq('some-name')
        expect(config_model.raw_manifest.fetch('key')).to eq('value')
      end
    end

  end
end
