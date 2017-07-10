require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20170606225018_add_cpi_to_cloud_records.rb' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170606225018_add_cpi_to_cloud_records.rb' }
    let(:created_at_time) { Time.now }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    describe 'backfilling orphaned_disks data' do
      it 'cpi is set when az is present in latest cloud config' do
        db[:orphan_disks] << { deployment_name: 'test-deployment', instance_name: 'test-instance', availability_zone: 'z1', disk_cid: 'disk-12345678', created_at: created_at_time }
        db[:cloud_configs] << { properties: "azs:\n- name: z1\n  cpi: my-cpi", created_at: created_at_time }

        DBSpecHelper.migrate(migration_file)

        subject = db[:orphan_disks].all[0]
        expect(subject[:availability_zone]).to eq('z1')
        expect(subject[:cpi]).to eq('my-cpi')
      end

      it 'cpi is empty when az is not present in latest cloud config' do
        db[:orphan_disks] << { deployment_name: 'test-deployment', instance_name: 'test-instance', availability_zone: 'z2', disk_cid: 'disk-12345678', created_at: created_at_time }
        db[:cloud_configs] << { properties: "azs:\n- name: z1\n  cpi: my-cpi", created_at: created_at_time }

        DBSpecHelper.migrate(migration_file)

        subject = db[:orphan_disks].all[0]
        expect(subject[:availability_zone]).to eq('z2')
        expect(subject[:cpi]).to eq('')
      end

      it 'cpi is empty when az does not configure cpi in latest cloud config' do
        db[:orphan_disks] << { deployment_name: 'test-deployment', instance_name: 'test-instance', availability_zone: 'z1', disk_cid: 'disk-12345678', created_at: created_at_time }
        db[:cloud_configs] << { properties: "azs:\n- name: z1\n  cpi: my-cpi\n- name: z2\n  cpi: my-cpi", created_at: created_at_time }
        db[:cloud_configs] << { properties: "azs:\n- name: z1\n- name: z2\n  cpi: my-cpi", created_at: created_at_time }

        DBSpecHelper.migrate(migration_file)

        subject = db[:orphan_disks].all[0]
        expect(subject[:availability_zone]).to eq('z1')
        expect(subject[:cpi]).to eq('')
      end

      it 'cpi is empty when az is not specified' do
        db[:orphan_disks] << { deployment_name: 'test-deployment', instance_name: 'test-instance', disk_cid: 'disk-12345678', created_at: created_at_time }
        db[:cloud_configs] << { properties: "azs:\n- name: z1\n- name: z2\n  cpi: my-cpi", created_at: created_at_time }

        DBSpecHelper.migrate(migration_file)

        subject = db[:orphan_disks].all[0]
        expect(subject[:availability_zone]).to be_nil
        expect(subject[:cpi]).to eq('')
      end

      it 'cpi is empty when there is no cloud config' do
        db[:orphan_disks] << { deployment_name: 'test-deployment', instance_name: 'test-instance', disk_cid: 'disk-12345678', created_at: created_at_time }

        DBSpecHelper.migrate(migration_file)

        subject = db[:orphan_disks].all[0]
        expect(subject[:availability_zone]).to be_nil
        expect(subject[:cpi]).to eq('')
      end

      it 'does not crash migration if cloud config is malformed' do
        db[:orphan_disks] << { deployment_name: 'test-deployment', instance_name: 'test-instance', availability_zone: 'z1', disk_cid: 'disk-12345678', created_at: created_at_time }
        db[:cloud_configs] << { properties: "{something", created_at: created_at_time }

        DBSpecHelper.migrate(migration_file)

        subject = db[:orphan_disks].all[0]
        expect(subject[:availability_zone]).to eq('z1')
        expect(subject[:cpi]).to eq('')
      end

      it 'cpi is empty when there are no azs defined in cloud config' do
        db[:orphan_disks] << { deployment_name: 'test-deployment', instance_name: 'test-instance', availability_zone: 'z1', disk_cid: 'disk-12345678', created_at: created_at_time }
        db[:cloud_configs] << { properties: "networks: []", created_at: created_at_time }

        DBSpecHelper.migrate(migration_file)

        subject = db[:orphan_disks].all[0]
        expect(subject[:availability_zone]).to eq('z1')
        expect(subject[:cpi]).to eq('')
      end
    end

    describe 'backfilling vms data' do
      it 'sets cpi according to versioned cloud config via instance and deployment' do
        db[:cloud_configs] << { properties: "azs:\n- name: z1\n  cpi: my-cpi", created_at: created_at_time }
        db[:deployments] << { name: 'deployment', cloud_config_id: 1 }
        db[:variable_sets] << { created_at: Time.now, deployment_id: 1 }
        db[:instances] << { availability_zone: 'z1', deployment_id: 1, state: 'running', job: 'instance-group-1', index: 0, variable_set_id: 1 }
        db[:vms] << { instance_id: 1 }

        DBSpecHelper.migrate(migration_file)

        subject = db[:vms].all[0]
        expect(subject[:cpi]).to eq('my-cpi')
      end

      it 'leaves cpi empty when there are no cloud configs' do
        db[:deployments] << { name: 'deployment' }
        db[:variable_sets] << { created_at: Time.now, deployment_id: 1 }
        db[:instances] << { availability_zone: 'z1', deployment_id: 1, state: 'running', job: 'instance-group-1', index: 0, variable_set_id: 1 }
        db[:vms] << { instance_id: 1 }

        DBSpecHelper.migrate(migration_file)

        subject = db[:vms].all[0]
        expect(subject[:cpi]).to eq('')
      end

      it 'leaves cpi empty when the instance does not have an az associated with it' do
        db[:cloud_configs] << { properties: "azs:\n- name: z1\n  cpi: my-cpi", created_at: created_at_time }
        db[:deployments] << { name: 'deployment', cloud_config_id: 1 }
        db[:variable_sets] << { created_at: Time.now, deployment_id: 1 }
        db[:instances] << { deployment_id: 1, state: 'running', job: 'instance-group-1', index: 0, variable_set_id: 1 }
        db[:vms] << { instance_id: 1 }

        DBSpecHelper.migrate(migration_file)

        subject = db[:vms].all[0]
        expect(subject[:cpi]).to eq('')
      end
    end
  end
end
