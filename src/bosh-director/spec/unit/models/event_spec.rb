require 'spec_helper'

module Bosh::Director::Models
  describe Event do
    it 'should save bigint ids' do
      expect {
        Event.make('id' => 9223372036854775807, 'parent_id' => 9223372036854775806)
      }.not_to raise_error
      expect(Event.where(id: 9223372036854775807).count).to eq(1)
    end

    it 'returns empty hash' do
      Event.make('id' => 7368734684376876503, 'parent_id' => 5223372036854775805, 'context' => nil)
      expect(Event.first.context).to eq({})
    end
  end
end
