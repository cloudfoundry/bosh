require 'spec_helper'
require 'bosh/director/models/deployment'

module Bosh::Director::Models
  describe Deployment do
    subject(:deployment) { described_class.make(manifest: manifest) }
    let(:manifest) { <<-HERE }
---
tags:
  - key: tag1
    value: value1
  - key: tag2
    value: value2
HERE

    describe '#tags' do
      it 'returns the tags in deployment manifest' do
        expect(deployment.tags).to eq({
          'tag1' => 'value1',
          'tag2' => 'value2',
        })
      end

      context 'when tags are not present' do
        let(:manifest) { '---{}' }

        it 'returns empty list' do
          expect(deployment.tags).to eq({})
        end
      end

      context 'when manifest is nil' do
        let(:manifest) { nil }

        it 'returns empty list' do
          expect(deployment.tags).to eq({})
        end
      end
    end
  end
end
