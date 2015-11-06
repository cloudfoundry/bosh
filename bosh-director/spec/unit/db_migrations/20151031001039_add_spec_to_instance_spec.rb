require 'spec_helper'

describe '20151031001039_add_spec_to_instance' do
  include Migrations

  before do
    during_migration('director') do |migration, db|
      migration.stop_before('20151031001039_add_spec_to_instance')

      db['INSERT INTO deployments (id, name) VALUES (789, "deployment")'].insert
      db["INSERT INTO vms (id, cid, agent_id, deployment_id, apply_spec_json) VALUES (1, 123, 456, 789, #{JSON.dump("{'empty' : 'value'}")})"].insert
      db['INSERT INTO instances (vm_id, job, "index", deployment_id, state) VALUES (1, "job", 1, 789, "started")'].insert

      migration.stop_after('20151031001039_add_spec_to_instance')
    end
  end

  it 'moves "Vm.apply_spec_json" to "Instance.spec_json"' do
    assert { |db|
      expect(db.fetch('SELECT * FROM vms').first[:cid]).to eq('123')
      expect(db.fetch('SELECT * FROM vms').first.has_key?(:apply_spec_json)).to eq(false)
      expect(db.fetch('SELECT * FROM instances').first[:spec_json]).to eq("{'empty' : 'value'}")
    }
  end
end