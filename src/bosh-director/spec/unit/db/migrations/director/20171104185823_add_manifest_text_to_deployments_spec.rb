require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'add_manifest_text_to_deployments' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20171104185823_add_manifest_text_to_deployments.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    it 'adds a manifest_text column that allows long text' do
      DBSpecHelper.migrate(migration_file)

      long_text = 'a' * 65536

      db[:deployments] << {id: 1, name: 'fake-deployment-name', manifest: '{}', manifest_text: long_text}

      deployment = db[:deployments].first
      expect(deployment[:manifest_text]).to eq(long_text)
    end

    context 'when manifest_text is nil or empty' do
      it 'puts manifest as manifest_text' do
        db[:deployments] << {id: 1, name: 'fake-deployment-name', manifest: YAML.dump({name: 'test'})}
        DBSpecHelper.migrate(migration_file)

        deployment = db[:deployments].first
        expect(deployment[:manifest_text]).to eq("---\n:name: test\n")
      end

      context 'when manifest is nil' do
        it 'puts default value' do
          db[:deployments] << {id: 1, name: 'fake-deployment-name', manifest: nil}
          DBSpecHelper.migrate(migration_file)

          deployment = db[:deployments].first
          expect(deployment[:manifest_text]).to eq("{}")
        end
      end
    end
  end
end
