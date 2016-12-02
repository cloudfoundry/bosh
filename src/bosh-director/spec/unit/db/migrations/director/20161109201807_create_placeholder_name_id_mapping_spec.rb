require 'db_spec_helper'

module Bosh::Director

  describe 'create table for holding placeholder name to placeholder id mapping' do

    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20161109201807_create_placeholder_name_id_mapping.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    context 'on upgrade' do

      before do
        expect(db.table_exists?(:placeholder_mappings)).to be_falsey
        DBSpecHelper.migrate(migration_file)
      end

      it 'should create placeholder_mappings table' do
        expect(db.table_exists?(:placeholder_mappings)).to be_truthy
      end

      it 'should set uniqueness constraint on placeholder_id and deployment_id pair' do

        db[:cloud_configs] << {properties: 'fake-cloud-config', created_at: '2011-04-01 18:00:00'}
        db[:runtime_configs] << {properties: 'fake-runtime-config', created_at: '2011-04-01 18:00:00'}
        db[:deployments] << {name: 'deployment1', cloud_config_id: 1, runtime_config_id: 1}

        db[:placeholder_mappings] << {placeholder_id: 1, placeholder_name: 'foo', deployment_id: 1}

        expect {
          db[:placeholder_mappings] << {placeholder_id: 1, placeholder_name: 'bar', deployment_id: 1}
        }.to raise_error Sequel::UniqueConstraintViolation

        expect {
          db[:placeholder_mappings] << {placeholder_id: 2, placeholder_name: 'bar', deployment_id: 1}
        }.to_not raise_error
      end
    end
  end
end
