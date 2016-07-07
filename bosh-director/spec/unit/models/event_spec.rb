require 'spec_helper'

module Bosh::Director::Models
  describe Event do
    it 'should save bigint ids' do
      expect {
        Event.make('id' => 9223372036854775807, 'parent_id' => 9223372036854775806)
      }.not_to raise_error
      expect(Event.where(id: 9223372036854775807).count).to eq(1)
    end
  end
end
