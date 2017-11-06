require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'add_raw_manifest_to_deployments' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20171104185823_add_raw_manifest_to_deployments.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    it 'adds a raw_manifest column that allows long text' do
      DBSpecHelper.migrate(migration_file)

      long_text = 'a' * 65536

      db[:deployments] << {id: 1, name: 'fake-deployment-name', manifest: '{}', raw_manifest: long_text}

      deployment = db[:deployments].first
      expect(deployment[:raw_manifest]).to eq(long_text)
    end

    context 'when raw_manifest is nil or empty' do
      it 'puts manifest as raw_manifest' do
        db[:deployments] << {id: 1, name: 'fake-deployment-name', manifest: YAML.dump({name: 'test'})}
        DBSpecHelper.migrate(migration_file)

        deployment = db[:deployments].first
        expect(deployment[:raw_manifest]).to eq("---\n:name: test\n")
      end

      context 'when manifest is nil' do
        it 'puts default value' do
          db[:deployments] << {id: 1, name: 'fake-deployment-name', manifest: nil}
          DBSpecHelper.migrate(migration_file)

          deployment = db[:deployments].first
          expect(deployment[:raw_manifest]).to eq("{}")
        end
      end
    end
  end
end
