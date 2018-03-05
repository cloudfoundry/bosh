require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'add stemcell api_version to vms and orphaned_vms' do
    let(:db) {DBSpecHelper.db}

    let(:migration_file) { '20180301204622_add_stemcell_api_version_to_vms.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      DBSpecHelper.migrate(migration_file)

      db[:deployments] << {id: 1, name: 'test-deployment'}
      db[:variable_sets] << {id: 1, deployment_id: 1, created_at: Time.now}
      db[:variables] << {variable_id: 1, variable_name: "test_variable", variable_set_id: 1}
      db[:instances] << {deployment_id: 1, job: 'test-job', index: 1, state: 'test', variable_set_id: 1}
    end

    it 'allows to save stemcell_api_version for vms' do
      db[:vms] << {id: 1, instance_id: 1}

      DBSpecHelper.migrate(migration_file)
      expect(db[:vms].columns).to include(:stemcell_api_version)

      db[:vms] << {id: 2, instance_id: 1}
      db[:vms] << {id: 3, instance_id: 1, stemcell_api_version: nil}
      db[:vms] << {id: 4, instance_id: 1, stemcell_api_version: 1}
      db[:vms] << {id: 5, instance_id: 1, stemcell_api_version: 2}

      expect(db[:vms].where(id: 1).first[:stemcell_api_version]).to eq(nil)
      expect(db[:vms].where(id: 2).first[:stemcell_api_version]).to eq(nil)
      expect(db[:vms].where(id: 3).first[:stemcell_api_version]).to eq(nil)
      expect(db[:vms].where(id: 4).first[:stemcell_api_version]).to eq(1)
      expect(db[:vms].where(id: 5).first[:stemcell_api_version]).to eq(2)
    end

    it 'allows to save stemcell_api_version for orphaned_vms' do
      db[:orphaned_vms] << {id: 1, cid: '1', instance_id: 1, orphaned_at: Time.now}

      DBSpecHelper.migrate(migration_file)
      expect(db[:orphaned_vms].columns).to include(:stemcell_api_version)

      db[:orphaned_vms] << {id: 2, cid: '2', instance_id: 1, orphaned_at: Time.now}
      db[:orphaned_vms] << {id: 3, cid: '3', instance_id: 1, stemcell_api_version: nil, orphaned_at: Time.now}
      db[:orphaned_vms] << {id: 4, cid: '4', instance_id: 1, stemcell_api_version: 1, orphaned_at: Time.now}
      db[:orphaned_vms] << {id: 5, cid: '5', instance_id: 1, stemcell_api_version: 2, orphaned_at: Time.now}

      expect(db[:orphaned_vms].where(id: 1).first[:stemcell_api_version]).to eq(nil)
      expect(db[:orphaned_vms].where(id: 2).first[:stemcell_api_version]).to eq(nil)
      expect(db[:orphaned_vms].where(id: 3).first[:stemcell_api_version]).to eq(nil)
      expect(db[:orphaned_vms].where(id: 4).first[:stemcell_api_version]).to eq(1)
      expect(db[:orphaned_vms].where(id: 5).first[:stemcell_api_version]).to eq(2)
    end
  end
end
