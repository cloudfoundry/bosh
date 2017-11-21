require 'db_spec_helper'

module Bosh::Director
  describe 'Add Runtime Config Name Support' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170427194511_add_runtime_config_name_support.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    it 'adds the name column to the runtime config table and defaults it to empty' do
      db[:runtime_configs] << {id: 100, properties: 'I am alive', created_at: Time.now}
      db[:runtime_configs] << {id: 200, properties: 'I am alive, too', created_at: Time.now}

      DBSpecHelper.migrate(migration_file)

      expect(db[:runtime_configs].where(id: 100).first[:name]).to eq('')
      expect(db[:runtime_configs].where(id: 200).first[:name]).to eq('')
    end

    it 'supports adding names to runtime config' do
      DBSpecHelper.migrate(migration_file)
      db[:runtime_configs] << {id: 100, properties: 'I am alive', name: 'CUSTOM_CONFIG_1', created_at: Time.now}
      db[:runtime_configs] << {id: 200, properties: 'I am alive', created_at: Time.now}

      expect(db[:runtime_configs].where(id: 100).first[:name]).to eq('CUSTOM_CONFIG_1')
      expect(db[:runtime_configs].where(id: 200).first[:name]).to eq('')
    end

    it 'does NOT support a null value for name' do
      DBSpecHelper.migrate(migration_file)

      expect{
        db[:runtime_configs] << {id: 100, properties: 'I am alive', name: nil, created_at: Time.now}
      }.to raise_error
    end
  end
end
