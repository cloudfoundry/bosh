require 'spec_helper'
require 'logger'
require 'bosh/director/models/package'

module Bosh::Director::Models
  describe Template do

    describe '#properties' do
      subject(:template) { described_class.make }

      context 'when null' do
        it 'returns empty hash' do
          expect(template.properties).to eq({})
        end
      end

      context 'when not null' do
        before do
          template.properties = {key: 'value'}
          template.save
        end

        it 'returns object' do
          expect(template.properties).to eq( { 'key' => 'value'} )
        end
      end
    end

  end
end

