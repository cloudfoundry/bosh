require 'spec_helper'

module Bosh::Director::Models
  describe Event, truncation: true do
    it 'should save bigint ids' do
      expect {
        FactoryBot.create(:models_event, id: 9223372036854775807, parent_id: 9223372036854775806)
      }.not_to raise_error
      expect(Event.where(id: 9223372036854775807).count).to eq(1)
    end

    it 'returns empty hash' do
      FactoryBot.create(:models_event, id: 7368734684376876503, parent_id: 5223372036854775805, context: nil)
      expect(Event.first.context).to eq({})
    end
  end
end
