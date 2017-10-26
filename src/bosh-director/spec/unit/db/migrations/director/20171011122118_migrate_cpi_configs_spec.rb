require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'cpi configs migrations' do
    let(:db) {DBSpecHelper.db}
    let(:migration_file) {'20171011122118_migrate_cpi_configs.rb'}
    let(:some_time) do
      Time.at(Time.now.to_i).utc
    end

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    it "copies 'cpi_configs' data into 'configs' table" do
      db[:cpi_configs] << { id: 3, properties: 'old content', created_at: some_time }

      DBSpecHelper.migrate(migration_file)

      expect(db[:configs].count).to eq(1)

      new_config = db[:configs].first
      expect(new_config).to include({
        type: 'cpi',
        name: 'default',
        content: 'old content',
        created_at: some_time
      })
    end
  end
end