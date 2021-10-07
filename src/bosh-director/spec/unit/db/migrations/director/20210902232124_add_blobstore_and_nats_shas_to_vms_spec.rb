require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20210902232124_add_blobstore_and_nats_shas_to_vms.rb' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20210902232124_add_blobstore_and_nats_shas_to_vms.rb' }
    let(:created_at_time) { Time.now }

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      allow(Bosh::Director::Config).to receive(:blobstore_config_fingerprint).and_return('blobstore-sha')
      allow(Bosh::Director::Config).to receive(:nats_config_fingerprint).and_return('nats-sha')
    end

    describe 'backfilling nats and blobstore sha1 data' do
      it 'fills in the nats and blobstore sha1s for existing vms' do
        db[:deployments] << { id: 1, name: 'some-deployment' }
        db[:variable_sets] << { id: 1, deployment_id: 1, created_at: Time.now }
        db[:instances] << { id: 1, job: 'some-job', index: 0, deployment_id: 1, state: 'running', variable_set_id: 1 }
        db[:instances] << { id: 2, job: 'some-job', index: 1, deployment_id: 1, state: 'running', variable_set_id: 1 }
        db[:vms] << { instance_id: 1 }
        db[:vms] << { instance_id: 2 }

        DBSpecHelper.migrate(migration_file)

        vm1 = db[:vms].all[0]
        vm2 = db[:vms].all[1]
        expect(vm1[:blobstore_config_sha1]).to eq('blobstore-sha')
        expect(vm1[:nats_config_sha1]).to eq('nats-sha')
        expect(vm2[:blobstore_config_sha1]).to eq('blobstore-sha')
        expect(vm2[:nats_config_sha1]).to eq('nats-sha')
      end
    end
  end
end
