require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20180410180821_migrate_legacy_update_strategy.rb' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20180410180821_migrate_legacy_update_strategy.rb' }
    let(:legacy_spec_json) do
      {
        'update' => {
          'strategy' => 'legacy',
        },
      }.to_json
    end

    let(:create_swap_delete_spec_json) do
      {
        'update' => {
          'strategy' => 'hot-swap',
        },
      }.to_json
    end

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:deployments] << { id: 1, name: 'fake-deployment-name', manifest: '{}' }
      db[:variable_sets] << { id: 100, deployment_id: 1, created_at: Time.now }
      db[:instances] << {
        id: 1,
        job: 'fake-job',
        index: 1,
        deployment_id: 1,
        variable_set_id: 100,
        state: 'started',
        spec_json: legacy_spec_json,
      }
      db[:instances] << {
        id: 2,
        job: 'fake-job',
        index: 1,
        deployment_id: 1,
        variable_set_id: 100,
        state: 'started',
        spec_json: create_swap_delete_spec_json,
      }
    end

    it 'should update the update strategies to their valid names' do
      DBSpecHelper.migrate(migration_file)

      expect(db[:instances].count).to eq(2)
      updated_legacy_spec_json = JSON.parse(db[:instances].all[0][:spec_json])
      expect(updated_legacy_spec_json['update']['strategy']).to eq('delete-create')
      updated_create_swap_delete_spec_json = JSON.parse(db[:instances].all[1][:spec_json])
      expect(updated_create_swap_delete_spec_json['update']['strategy']).to eq('create-swap-delete')
    end

    context 'with invalid json' do
      let(:legacy_spec_json) { '{{' }

      it 'moves on to the next records' do
        DBSpecHelper.migrate(migration_file)

        expect(db[:instances].count).to eq(2)
        expect(db[:instances].all[0][:spec_json]).to eq('{{')
        updated_create_swap_delete_spec_json = JSON.parse(db[:instances].all[1][:spec_json])
        expect(updated_create_swap_delete_spec_json['update']['strategy']).to eq('create-swap-delete')
      end
    end

    context 'when the update key does not exist' do
      let(:legacy_spec_json) { '{}' }

      it 'does not migrate that spec_json' do
        DBSpecHelper.migrate(migration_file)

        expect(db[:instances].count).to eq(2)
        expect(db[:instances].all[0][:spec_json]).to eq('{}')
        updated_create_swap_delete_spec_json = JSON.parse(db[:instances].all[1][:spec_json])
        expect(updated_create_swap_delete_spec_json['update']['strategy']).to eq('create-swap-delete')
      end
    end
  end
end
