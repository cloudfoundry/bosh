require 'db_spec_helper'

module Bosh::Director
describe 'add_writable_to_variable_set' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170321151400_add_writable_to_variable_set.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      db[:deployments] << {id: 1, name: 'deployment_1'}
      db[:deployments] << {id: 2, name: 'deployment_2'}

      DBSpecHelper.migrate(migration_file)

      db[:variable_sets] << {id: 100, deployment_id: 1, created_at: Time.now}
      db[:variable_sets] << {id: 200, deployment_id: 1, created_at: Time.now}
      db[:variable_sets] << {id: 300, deployment_id: 2, created_at: Time.now}
    end

    it 'sets the writable field as false for migrated records' do
        db[:variable_sets].map do |vs|
          expect(vs[:writable]).to eq(false)
        end
    end
  end
end
