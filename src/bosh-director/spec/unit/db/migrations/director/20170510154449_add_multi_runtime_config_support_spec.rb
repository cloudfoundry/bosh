require 'db_spec_helper'

module Bosh::Director
  describe 'Add Multi-Runtime-Config Support' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170510154449_add_multi_runtime_config_support.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:runtime_configs] << {id: 100, properties: 'version_1', created_at: Time.now}
      db[:runtime_configs] << {id: 200, properties: 'version_2', created_at: Time.now}
      db[:runtime_configs] << {id: 300, properties: 'version_3', created_at: Time.now}

      db[:deployments] << {id: 1, name: 'deployment_1', runtime_config_id: 100}
      db[:deployments] << {id: 2, name: 'deployment_2', runtime_config_id: 100}
      db[:deployments] << {id: 3, name: 'deployment_3', runtime_config_id: 200}
      db[:deployments] << {id: 4, name: 'deployment_4'}
    end

    it 'should migrate existing deployment records to reflect many-to-many relationship between deployments & runtime config' do
      DBSpecHelper.migrate(migration_file)

      expect(db[:deployments_runtime_configs].all).to contain_exactly(
         {:deployment_id=>1, :runtime_config_id=>100},
         {:deployment_id=>2, :runtime_config_id=>100},
         {:deployment_id=>3, :runtime_config_id=>200}
       )
    end

    it 'removes runtime config foreign key column and reference in the deployment table' do
      DBSpecHelper.migrate(migration_file)

      expect(db[:deployments].all.count).to eq(4)
      db[:deployments].all.each do |deployment|
        expect(deployment.key?(:runtime_config_id)).to be_falsey
      end
    end
  end
end
