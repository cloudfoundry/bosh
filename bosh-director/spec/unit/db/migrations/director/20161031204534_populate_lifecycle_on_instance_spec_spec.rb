require 'db_spec_helper'

module Bosh::Director
  describe 'populating lifecycle on instance spec json' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20161031204534_populate_lifecycle_on_instance_spec.rb' }

    let(:manifest_yml) { YAML.dump({'instance_groups' => [{'name' => 'noise'}, instance_group_hash]}) }
    let(:spec_json) { JSON.dump({}) }

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:deployments] << {id: 1, name: 'fake-deployment-name', manifest: manifest_yml}
      db[:instances] << {id: 1, job: 'normal_job', index: 1, deployment_id: 1, state: 'started', spec_json: spec_json}

      DBSpecHelper.migrate(migration_file)
    end

    context 'when the group does not declare a lifecycle' do
      let(:instance_group_hash) { {'name' => 'normal_job'} }
      it 'defaults the spec_json lifecycle to service' do
        expect(JSON.parse(db[:instances].where(id: 1).first[:spec_json])).to eq('lifecycle' => 'service')
      end
    end

    context 'when the group declares a errand lifecycle' do
      let(:instance_group_hash) { {'name' => 'normal_job', 'lifecycle' => 'errand'} }
      it 'sets the spec_json lifecyle to errand' do
        expect(JSON.parse(db[:instances].where(id: 1).first[:spec_json])).to eq('lifecycle' => 'errand')
      end
    end

    context 'when the group declares a service lifecycle' do
      let(:instance_group_hash) { {'name' => 'normal_job', 'lifecycle' => 'service'} }
      it 'sets the spec_json lifecycle to service' do
        expect(JSON.parse(db[:instances].where(id: 1).first[:spec_json])).to eq('lifecycle' => 'service')
      end
    end

    context 'when the manifest is nil' do
      let(:manifest_yml) { nil }
      it 'does not update the spec_json' do
        expect(JSON.parse(db[:instances].where(id: 1).first[:spec_json])).to eq({})
      end
    end

    context 'when the manifest is empty string' do
      let(:manifest_yml) { "" }
      it 'does not update the spec_json' do
        expect(JSON.parse(db[:instances].where(id: 1).first[:spec_json])).to eq({})
      end
    end

    context 'when the manifest contains a jobs section (and not instance_groups)' do
      let(:manifest_yml) { JSON.dump({'jobs' => [{'name' => 'normal_job'}]}) }
      it 'sets the spec_json lifecycle to service' do
        expect(JSON.parse(db[:instances].where(id: 1).first[:spec_json])).to eq('lifecycle' => 'service')
      end
    end

    context 'when the manifest does not contain either jobs or instance_groups' do
      let(:manifest_yml) { JSON.dump({}) }
      it 'does not update the spec_json' do
        expect(JSON.parse(db[:instances].where(id: 1).first[:spec_json])).to eq({})
      end
    end

    context 'when the spec already has unrelated content' do
      let(:instance_group_hash) { {'name' => 'normal_job'} }
      let(:spec_json) { JSON.dump({'derek' => 'tyler'}) }
      it 'does not update the spec_json' do
        expect(JSON.parse(db[:instances].where(id: 1).first[:spec_json])).to eq({'derek' => 'tyler', 'lifecycle' => 'service'})
      end
    end

    context 'when the instance has nil spec_json' do
      let(:instance_group_hash) { {'name' => 'normal_job'} }
      let(:spec_json) { nil }
      it 'does not update the spec_json' do
        expect(db[:instances].where(id: 1).first[:spec_json]).to eq(nil)
      end
    end

    context 'when the instance has "" spec_json' do
      let(:instance_group_hash) { {'name' => 'normal_job'} }
      let(:spec_json) { "" }
      it 'does not update the spec_json' do
        expect(db[:instances].where(id: 1).first[:spec_json]).to eq("")
      end
    end

    context 'when the manifest does not contain the instance group name' do
      let(:instance_group_hash) { {'name' => 'job_that_does_not_exist', 'lifecycle' => 'service'} }
      it 'does not update the spec json' do
        expect(JSON.parse(db[:instances].where(id: 1).first[:spec_json])).to eq({})
      end
    end
  end
end
