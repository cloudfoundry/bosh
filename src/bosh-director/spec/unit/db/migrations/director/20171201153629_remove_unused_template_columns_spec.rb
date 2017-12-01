require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'Delete column from template table' do
    let(:db) {DBSpecHelper.db}
    let(:migration_file) {'20171201153629_remove_unused_template_columns.rb'}

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      DBSpecHelper.migrate(migration_file)
    end

    it 'should remove provides_json column' do
      expect(db[:templates].columns.include?(:provides_json)).to be_falsey
    end

    it 'should remove consumes_json column' do
      expect(db[:templates].columns.include?(:consumes_json)).to be_falsey
    end

    it 'should remove properties_json column' do
      expect(db[:templates].columns.include?(:properties_json)).to be_falsey
    end

    it 'should remove logs_json column' do
      expect(db[:templates].columns.include?(:logs_json)).to be_falsey
    end

    it 'should remove templates_json column' do
      expect(db[:templates].columns.include?(:templates_json)).to be_falsey
    end
  end
end
