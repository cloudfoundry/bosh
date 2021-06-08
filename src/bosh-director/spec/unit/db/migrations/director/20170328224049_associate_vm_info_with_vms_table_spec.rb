require 'db_spec_helper'

module Bosh::Director
  describe 'associate_vm_info_with_vms_table' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170328224049_associate_vm_info_with_vms_table.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:deployments] << {name: 'foo'}
      db[:variable_sets] << {deployment_id: db[:deployments].first[:id], created_at: Time.now}
    end

    it 'should reset vms table' do
      expect(db.table_exists?('vms')).to be_truthy
      db[:vms] << {agent_id: 1, deployment_id: db[:deployments].first[:id]}

      DBSpecHelper.migrate(migration_file)
      expect(db.table_exists?('vms')).to be_truthy

      expect(db[:vms].all.length).to eq(0)
      expect(db[:vms].columns).to contain_exactly(:id, :cid, :agent_id, :credentials_json, :trusted_certs_sha1, :instance_id)
    end

    it 'drops the vm_id from instances table' do
      expect(db[:instances].columns.include?(:vm_id)).to be_truthy

      DBSpecHelper.migrate(migration_file)
      expect(db[:instances].columns.include?(:vm_id)).to be_falsey
    end

    it 'has a unique contraint on the agent_id for the vm table' do
      DBSpecHelper.migrate(migration_file)

      db[:instances] << {id: 1, job: 'blah', index: 0, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running'}
      db[:vms] << {agent_id: 1, instance_id: 1}
      expect { db[:vms] << {agent_id: 1, instance_id: 1} }.to raise_error(Sequel::UniqueConstraintViolation)
    end

    it 'has a unique contraint on the cid for the vm table' do
      DBSpecHelper.migrate(migration_file)

      db[:instances] << {id: 1, job: 'blah', index: 0, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running'}
      db[:vms] << {cid: 1, instance_id: 1}
      expect { db[:vms] << {cid: 1, instance_id: 1} }.to raise_error(Sequel::UniqueConstraintViolation)
    end

    it 'has a foreign key to the instances table on the instances id for the vm table' do
      DBSpecHelper.migrate(migration_file)
      expect { db[:vms] << {instance_id: 999} }.to raise_error(Sequel::ForeignKeyConstraintViolation)
    end

    it 'has a not null constraint on the instances id for the vm table' do
      DBSpecHelper.migrate(migration_file)
      expect { db[:vms] << {} }.to raise_error(/NOT NULL constraint failed: vms.instance_id/)
    end

    it 'defaults the trusted certs sha1 to the sha of an empty string for the vm table' do
      DBSpecHelper.migrate(migration_file)

      db[:instances] << {id: 1, job: 'blah', index: 0, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running'}
      db[:vms] << {cid: 1, instance_id: 1}
      expect(db[:vms].all.first[:trusted_certs_sha1]).to eq('da39a3ee5e6b4b0d3255bfef95601890afd80709')
    end

    it 'adds foreign key constraint on active_vm_id to instances' do
      db[:variable_sets] << {deployment_id: db[:deployments].first[:id], created_at: Time.now}

      DBSpecHelper.migrate(migration_file)
      expect {
        db[:instances] << {id: 0, active_vm_id: 666, job: 'blah', index: 0, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running'}
      }.to raise_error Sequel::ForeignKeyConstraintViolation
    end

    describe 'populating vms table' do
      before do
        db[:variable_sets] << {deployment_id: db[:deployments].first[:id], created_at: Time.now}
        db[:instances] << {id: 1, job: 'blah', index: 0, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running', agent_id: 99, vm_cid: 100, credentials_json: '{"foo":"bar"}', trusted_certs_sha1: 'some-trusted-cert-sha1'}
        db[:instances] << {id: 2, job: 'blah', index: 1, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running', agent_id: 100, vm_cid: 101, credentials_json: '{"foo":"bar"}', trusted_certs_sha1: 'some-trusted-cert-sha1'}
        db[:instances] << {id: 3, job: 'blah', index: 2, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running', agent_id: 101, vm_cid: 102, credentials_json: '{"foo":"bar"}', trusted_certs_sha1: 'some-trusted-cert-sha1'}
        db[:instances] << {id: 4, job: 'blah', index: 3, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running', agent_id: 103, credentials_json: '{"foo":"bar"}', trusted_certs_sha1: 'some-trusted-cert-sha1'}
        db[:instances] << {id: 5, job: 'blah', index: 4, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running', agent_id: 102, vm_cid: 103, credentials_json: '{"foo":"bar"}', trusted_certs_sha1: 'some-trusted-cert-sha1'}
      end

      it 'uses existing values in the instances table when instance has vm_cid' do
        DBSpecHelper.migrate(migration_file)
        expect(db[:vms].all).to contain_exactly(
          {id: 1, instance_id: 1, agent_id: '99', cid: '100', credentials_json: '{"foo":"bar"}', trusted_certs_sha1: 'some-trusted-cert-sha1'},
          {id: 2, instance_id: 2, agent_id: '100', cid: '101', credentials_json: '{"foo":"bar"}', trusted_certs_sha1: 'some-trusted-cert-sha1'},
          {id: 3, instance_id: 3, agent_id: '101', cid: '102', credentials_json: '{"foo":"bar"}', trusted_certs_sha1: 'some-trusted-cert-sha1'},
          {id: 4, instance_id: 5, agent_id: '102', cid: '103', credentials_json: '{"foo":"bar"}', trusted_certs_sha1: 'some-trusted-cert-sha1'}
        )

        expect(db[:instances].where(id: 1).first[:active_vm_id]).to eq(1)
        expect(db[:instances].where(id: 2).first[:active_vm_id]).to eq(2)
        expect(db[:instances].where(id: 3).first[:active_vm_id]).to eq(3)
        expect(db[:instances].where(id: 4).first[:active_vm_id]).to be_nil
        expect(db[:instances].where(id: 5).first[:active_vm_id]).to eq(4)
      end
    end

    describe 'backing up important columns' do
      before do
        db[:variable_sets] << {deployment_id: db[:deployments].first[:id], created_at: Time.now}
        db[:instances] << {id: 1, job: 'blah', index: 0, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running', agent_id: 99, vm_cid: 100, credentials_json: '{"foo":"bar"}', trusted_certs_sha1: 'some-trusted-cert-sha1'}
        db[:instances] << {id: 2, job: 'blah', index: 1, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running', agent_id: 100, vm_cid: 101, credentials_json: '{"foo":"bar"}', trusted_certs_sha1: 'some-trusted-cert-sha1'}
        db[:instances] << {id: 3, job: 'blah', index: 2, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running', agent_id: 101, vm_cid: 102, credentials_json: '{"foo":"bar"}', trusted_certs_sha1: 'some-trusted-cert-sha1'}
        db[:instances] << {id: 4, job: 'blah', index: 3, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running', agent_id: 102, credentials_json: '{"foo":"bar"}', trusted_certs_sha1: 'some-trusted-cert-sha1'}
        db[:instances] << {id: 5, job: 'blah', index: 4, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running', agent_id: 103, vm_cid: 103, credentials_json: '{"foo":"bar"}', trusted_certs_sha1: 'some-trusted-cert-sha1'}
      end

      it 'renames columns transferred to vms table (vm_cid, credentials_json, agent_id, trusted_certs_sha1)' do
        DBSpecHelper.migrate(migration_file)
        expect(db[:instances].all).to contain_exactly(
          {id: 1, active_vm_id: 1, job: 'blah', index: 0, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running', agent_id_bak: '99', vm_cid_bak: '100', credentials_json_bak: '{"foo":"bar"}', trusted_certs_sha1_bak: 'some-trusted-cert-sha1', resurrection_paused: false, uuid: nil, availability_zone: nil, cloud_properties: nil, compilation: false, bootstrap: false, dns_records: nil, spec_json: nil, update_completed: false, ignore: false },
          {id: 2, active_vm_id: 2, job: 'blah', index: 1, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running', agent_id_bak: '100', vm_cid_bak: '101', credentials_json_bak: '{"foo":"bar"}', trusted_certs_sha1_bak: 'some-trusted-cert-sha1', resurrection_paused: false, uuid: nil, availability_zone: nil, cloud_properties: nil, compilation: false, bootstrap: false, dns_records: nil, spec_json: nil, update_completed: false, ignore: false },
          {id: 3, active_vm_id: 3, job: 'blah', index: 2, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running', agent_id_bak: '101', vm_cid_bak: '102', credentials_json_bak: '{"foo":"bar"}', trusted_certs_sha1_bak: 'some-trusted-cert-sha1', resurrection_paused: false, uuid: nil, availability_zone: nil, cloud_properties: nil, compilation: false, bootstrap: false, dns_records: nil, spec_json: nil, update_completed: false, ignore: false },
          {id: 4, active_vm_id: nil, job: 'blah', index: 3, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running', agent_id_bak: '102', vm_cid_bak: nil, credentials_json_bak: '{"foo":"bar"}', trusted_certs_sha1_bak: 'some-trusted-cert-sha1', resurrection_paused: false, uuid: nil, availability_zone: nil, cloud_properties: nil, compilation: false, bootstrap: false, dns_records: nil, spec_json: nil, update_completed: false, ignore: false },
          {id: 5, active_vm_id: 4, job: 'blah', index: 4, deployment_id: db[:deployments].first[:id], variable_set_id: db[:variable_sets].first[:id], state: 'running', agent_id_bak: '103', vm_cid_bak: '103', credentials_json_bak: '{"foo":"bar"}', trusted_certs_sha1_bak: 'some-trusted-cert-sha1', resurrection_paused: false, uuid: nil, availability_zone: nil, cloud_properties: nil, compilation: false, bootstrap: false, dns_records: nil, spec_json: nil, update_completed: false, ignore: false },
        )
      end
    end
  end
end
