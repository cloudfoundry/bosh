require 'db_spec_helper'

module Bosh::Director
  describe '20230103143246_add_permanent_nats_credentials_to_vms.rb' do
    subject(:migration) { '20230103143246_add_permanent_nats_credentials_to_vms.rb' }
    let(:db) { DBSpecHelper.db }
    let(:created_at_time) { Time.now }

    before do
      DBSpecHelper.migrate_all_before(subject)
      db[:deployments] << { id: 1, name: 'fake-deployment-name', manifest: '{}' }
      db[:variable_sets] << { deployment_id: db[:deployments].first[:id], created_at: Time.now }
      db[:instances] << {
        id: 1,
        job: 'fake-instance-group',
        uuid: 'uuid1',
        index: 1,
        deployment_id: 1,
        state: 'started',
        availability_zone: 'az1',
        variable_set_id: 1,
        spec_json: '{}',
      }
      attrs = {
        id: 1,
        instance_id: 1,
        agent_id: 'fake-agent-id-1',
        cid: 'fake-vm-cid-1',
        env_json: 'fake-env-json',
        trusted_certs_sha1: 'fake-trusted-certs-sha1',
      }
      db[:vms] << attrs

      DBSpecHelper.migrate(subject)
    end

    it 'should add permanent_nats_credentials to the vms table' do
      expect(db[:vms].columns).to include(:permanent_nats_credentials)
    end

    it 'should migrate existing vms records to permanent_nats_credentials equals false' do
      expect(db[:vms].where(id: 1).first[:permanent_nats_credentials]).to eq(false)
    end

    it 'should add new vm records with permanent_nats_credentials equals false' do
      db[:instances] << {
        id: 2,
        job: 'fake-instance-group',
        uuid: 'uuid2',
        index: 1,
        deployment_id: 1,
        state: 'started',
        availability_zone: 'az1',
        variable_set_id: 1,
        spec_json: '{}',
      }
      attrs = {
        id: 2,
        instance_id: 2,
        agent_id: 'fake-agent-id-2',
        cid: 'fake-vm-cid-2',
        env_json: 'fake-env-json',
        trusted_certs_sha1: 'fake-trusted-certs-sha1',
      }
      db[:vms] << attrs

      expect(db[:vms].where(id: 2).first[:permanent_nats_credentials]).to eq(false)
    end

    it 'should add new vm records with permanent_nats_credentials equals true.' do
      db[:instances] << {
        id: 2,
        job: 'fake-instance-group',
        uuid: 'uuid2',
        index: 1,
        deployment_id: 1,
        state: 'started',
        availability_zone: 'az1',
        variable_set_id: 1,
        spec_json: '{}',
      }
      attrs = {
        id: 2,
        instance_id: 2,
        agent_id: 'fake-agent-id-2',
        cid: 'fake-vm-cid-2',
        env_json: 'fake-env-json',
        trusted_certs_sha1: 'fake-trusted-certs-sha1',
        permanent_nats_credentials: true,
      }
      db[:vms] << attrs

      expect(db[:vms].where(id: 2).first[:permanent_nats_credentials]).to eq(true)
    end
  end
end
