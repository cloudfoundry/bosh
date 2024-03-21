require 'db_spec_helper'

module Bosh::Director
  describe '20240319204601_remove_dns_records_from_instances.rb' do
    let(:db) { DBSpecHelper.db }

    before do
      DBSpecHelper.migrate_all_before(subject)
    end

    it 'drops resurrection_paused column from instances table' do
      expect(db[:instances].columns.include?(:dns_records)).to be_truthy
      DBSpecHelper.migrate(subject)
      expect(db[:instances].columns.include?(:dns_records)).to be_falsey
    end
  end
end
