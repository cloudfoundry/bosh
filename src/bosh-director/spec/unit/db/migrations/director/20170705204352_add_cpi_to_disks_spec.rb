require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20170705204352_add_cpi_to_disks.rb' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170705204352_add_cpi_to_disks.rb' }
    let(:created_at_time) { Time.now }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    describe 'backfilling persistent_disks data' do
      let(:cloud_config_properties) { {} }

      before do
        db[:cloud_configs] << { properties: cloud_config_properties.to_yaml, created_at: created_at_time, id: 37 }
        db[:deployments] << { name: 'fake-deployment', id: 42 }
        db[:variable_sets] << { id: 57, deployment_id: 42, created_at: created_at_time }
        db[:instances] << { id: 123, availability_zone: 'z1', deployment_id: 42, job: 'instance_job', index: 23, state: 'started', variable_set_id: 57 }
        db[:persistent_disks] << { disk_cid: 'disk-12345678', instance_id: 123 }
      end

      context 'using cloud config' do
        let(:cloud_config_properties) { { 'azs' => [ { 'name' => 'z1', 'cpi' => 'my-cpi' } ] } }

        before do
          db[:deployments].where(id: 42).update(cloud_config_id: 37)
        end

        it 'sets the cpi' do
          DBSpecHelper.migrate(migration_file)
          subject = db[:persistent_disks].all[0]
          expect(subject[:cpi]).to eq('my-cpi')
        end

        context 'az does not configure cpi' do
          let(:cloud_config_properties) { { 'azs' => [ { 'name' => 'z1' } ] } }

          it 'does not assign cpi to disk' do
            DBSpecHelper.migrate(migration_file)
            subject = db[:persistent_disks].all[0]
            expect(subject[:cpi]).to eq('')
          end
        end

        context 'if cloud config has 3 AZs, in an instance without an AZ' do
          let(:cloud_config_properties) { {
            'azs' => [
              { 'name' => 'z4', 'cpi' => 'my-cpi-1' },
              { 'name' => 'z2', 'cpi' => 'my-cpi-2' },
              { 'name' => 'z3', 'cpi' => 'my-cpi-3' },
            ]
          } }

          it 'does not assign cpi to disk' do
            DBSpecHelper.migrate(migration_file)
            subject = db[:persistent_disks].all[0]
            expect(subject[:cpi]).to eq('')
          end
        end

        context 'if no AZs defined' do
          let(:cloud_config_properties) {{}}

          it 'does not assign cpi to disk' do
            DBSpecHelper.migrate(migration_file)
            subject = db[:persistent_disks].all[0]
            expect(subject[:cpi]).to eq('')
          end
        end

        context 'if the cloud config is badly formed' do
          it 'does not assign cpi to disk' do
            db[:cloud_configs].where(id: 37).update(properties: 'true: true: true')
            DBSpecHelper.migrate(migration_file)
            subject = db[:persistent_disks].all[0]
            expect(subject[:cpi]).to eq('')
          end
        end
      end

      context 'without cloud config' do
        it 'if the deployment does not use cloud config' do
          DBSpecHelper.migrate(migration_file)
          subject = db[:persistent_disks].all[0]
          expect(subject[:cpi]).to eq('')
        end
      end
    end
  end
end
