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

    it 'removes old tombstone records' do
      previous_record = Bosh::Director::Models::LocalDnsRecord.insert_tombstone
      new_record = Bosh::Director::Models::LocalDnsRecord.insert_tombstone
      expect(Bosh::Director::Models::LocalDnsRecord.where(id: previous_record.id).first).to be_nil
      expect(Bosh::Director::Models::LocalDnsRecord.where(id: new_record.id).first).not_to be_nil
    end
  end
end
