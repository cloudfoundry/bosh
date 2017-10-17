require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'cloud configs migrations' do
    let(:db) {DBSpecHelper.db}
    let(:migration_file) {'20171010161532_migrate_cloud_configs.rb'}
    let(:some_time) do
      Time.at(Time.now.to_i).utc
    end

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    it "copies 'cloud_configs' data into 'configs' table and updates 'deployments_configs' table" do
      db[:cloud_configs] << { id: 3, properties: 'old content', created_at: some_time }
      db[:deployments] << { id: 2, name: 'fake-name', cloud_config_id: 3}

      DBSpecHelper.migrate(migration_file)

      expect(db[:configs].count).to eq(1)
      deployment_config = db[:deployments_configs].first
      expect(deployment_config[:config_id]).to be
      new_config = db[:configs].where(id: deployment_config[:config_id]).first
      expect(new_config).to include({
        type: 'cloud',
        name: 'default',
        content: 'old content',
        created_at: some_time
      })
    end

    it "drops the foreign key `cloud_config_id` from `deployments`" do
      expect(db[:deployments].columns.include?(:cloud_config_id)).to be_truthy

      DBSpecHelper.migrate(migration_file)

      expect(db[:deployments].columns.include?(:cloud_config_id)).to be_falsey
    end
  end
end