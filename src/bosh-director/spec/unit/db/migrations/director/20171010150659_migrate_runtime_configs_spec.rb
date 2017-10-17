require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'runtime configs migration' do
    let(:db) {DBSpecHelper.db}
    let(:migration_file) {'20171010150659_migrate_runtime_configs.rb'}
    let(:some_time) do
      Time.at(Time.now.to_i).utc
    end

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    it "creates table 'deployments_configs' and derives content from 'deployments_runtime_configs'" do
      db[:deployments] << { name: 'fake-name'}
      db[:runtime_configs] << { properties: 'old content with name', name: 'old_name', created_at: some_time }
      db[:deployments_runtime_configs] << { deployment_id: 1, runtime_config_id: 1 }

      DBSpecHelper.migrate(migration_file)

      deployment_runtime = db[:deployments_configs].first
      expect(deployment_runtime).to be
      expect(deployment_runtime[:deployment_id]).to be 1
      expect(deployment_runtime[:config_id]).to be 1
    end

    context 'without name' do
      it "copies 'runtime_configs' data into 'configs' table and updates 'deployments_configs' table" do
        db[:deployments] << { id: 2, name: 'fake-name'}
        db[:runtime_configs] << { id: 3, properties: 'old content', created_at: some_time }
        db[:deployments_runtime_configs] << { deployment_id: 2, runtime_config_id: 3 }

        DBSpecHelper.migrate(migration_file)

        expect(db[:configs].count).to eq(1)
        deployment_runtime = db[:deployments_configs].first
        expect(deployment_runtime[:config_id]).to be
        new_config = db[:configs].where(id: deployment_runtime[:config_id]).first
        expect(new_config).to include({
          type: 'runtime',
          name: 'default',
          content: 'old content',
          created_at: some_time
        })
      end
    end

    context 'with name' do
      it 'copies config data into config table and updates deployments runtime configs table' do
        db[:deployments] << { name: 'fake-name'}
        db[:runtime_configs] << { properties: 'old content with name', name: 'old_name', created_at: some_time }
        db[:deployments_runtime_configs] << { deployment_id: 1, runtime_config_id: 1 }

        DBSpecHelper.migrate(migration_file)

        deployment_runtime_with_name = db[:deployments_configs].first
        expect(deployment_runtime_with_name[:config_id]).to be
        new_config_with_name = db[:configs].where(id: deployment_runtime_with_name[:config_id]).first
        expect(new_config_with_name).to include({
          type: 'runtime',
          name: 'old_name',
          content: 'old content with name',
          created_at: some_time
        })
      end

      it "'default' gets renamed to 'default-<UUID>'" do
        allow(SecureRandom).to receive(:uuid).and_return('fakeUUID')
        db[:deployments] << { name: 'fake-name'}
        db[:runtime_configs] << { properties: 'old content with name', name: 'default', created_at: some_time }
        db[:deployments_runtime_configs] << { deployment_id: 1, runtime_config_id: 1 }

        DBSpecHelper.migrate(migration_file)

        deployment_runtime_with_name = db[:deployments_configs].first
        expect(deployment_runtime_with_name[:config_id]).to be
        new_config_with_name = db[:configs].where(id: deployment_runtime_with_name[:config_id]).first
        expect(new_config_with_name).to include({
          type: 'runtime',
          name: 'default-fakeUUID',
          content: 'old content with name',
          created_at: some_time
        })
      end
    end

    it "drops 'deployments_runtime_config' table" do
      expect(db.tables).to include(:deployments_runtime_configs)
      DBSpecHelper.migrate(migration_file)
      expect(db.tables).to_not include(:deployments_runtime_configs)
    end
  end
end