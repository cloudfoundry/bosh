require 'db_spec_helper'

module Bosh::Director
  describe '20171018102040_remove_compilation_local_dns_records' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20171018102040_remove_compilation_local_dns_records.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:deployments] << {id: 1, name: 'fake-deployment', manifest: '{}'}
      db[:variable_sets] << {deployment_id: 1, created_at: Time.now}

      db[:instances] << {
        job: "fake-ig",
        uuid: "fake-uuid1",
        index: 1,
        deployment_id: 1,
        compilation: compilation,
        state: "started",
        availability_zone: "fake-az1",
        variable_set_id: 1,
        spec_json: "{}",
      }
      db[:local_dns_records] << {
        instance_id: 1,
        instance_group: "fake-ig",
        az: "fake-az",
        network: "fake-network",
        deployment: "fake-deployment",
        ip: "192.0.2.1",
      }
    end

    context 'compilation instances' do
      let(:compilation) { true }

      it 'removes local dns records which referenced compilation instances' do
        DBSpecHelper.migrate(migration_file)

        expect(db[:local_dns_records].all.size).to eq(0)
      end
    end

    context 'non-compilation instances' do
      let(:compilation) { false }

      it 'retains local dns records' do
        DBSpecHelper.migrate(migration_file)

        expect(db[:local_dns_records].all.size).to eq(1)
      end
    end
  end
end
