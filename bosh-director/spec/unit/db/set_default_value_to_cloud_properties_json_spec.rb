require 'db_spec_helper'

module Bosh::Director
  describe 'set default value to cloud properties json' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20160223124032_set_default_value_to_cloud_properties_json.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'runs set_value_to_cloud_properties_json migration' do
      db[:persistent_disks] << {id: 1, cloud_properties_json: ''}
      expect(db[:persistent_disks].first[:cloud_properties_json]).to eq('')

      DBSpecHelper.migrate(migration_file)

      expect(db[:persistent_disks].first[:cloud_properties_json]).to eq('{}')
    end
  end
end