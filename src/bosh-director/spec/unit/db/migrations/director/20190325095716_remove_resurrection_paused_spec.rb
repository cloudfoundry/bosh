require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20190325095716_remove_resurrection_paused.rb' do
    let(:db) { DBSpecHelper.db }

    before do
      DBSpecHelper.migrate_all_before(subject)
    end

    it 'drops resurrection_paused column from instances table' do
      expect(db[:instances].columns.include?(:resurrection_paused)).to be_truthy
      DBSpecHelper.migrate(subject)
      expect(db[:instances].columns.include?(:resurrection_paused)).to be_falsey
    end
  end
end
