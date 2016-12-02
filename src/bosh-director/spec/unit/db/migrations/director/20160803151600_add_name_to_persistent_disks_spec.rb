require 'db_spec_helper'

module Bosh::Director
  describe 'adding name to persistent disk' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20160803151600_add_name_to_persistent_disks.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'sets the default value of the persistent disk name to empty string' do
      db[:deployments] << {id: 1, name: 'fake-deployment-name', manifest: '{}'}
      db[:instances] << {id: 1, job: 'fake-job', index: 1, deployment_id: 1, state: 'started'}
      db[:persistent_disks] << {
        instance_id: 1,
        disk_cid: 'disk-cid',
        size: 1024,
        active: true,
      }

      DBSpecHelper.migrate(migration_file)

      expect(db[:persistent_disks].map{|pd| pd[:name]}).to eq([''])
    end
  end
end
