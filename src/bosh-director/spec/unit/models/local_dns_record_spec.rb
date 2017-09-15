require 'spec_helper'

module Bosh::Director::Models
  describe '#insert_tombstone' do
    it 'inserts a new record' do
      expect {
        Bosh::Director::Models::LocalDnsRecord.insert_tombstone
      }.to change {
        Bosh::Director::Models::LocalDnsRecord.all.count
      }.from(0).to(1)

      expect(Bosh::Director::Models::LocalDnsRecord.first.instance).to be_nil
    end
  end
end
