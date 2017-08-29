require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'add_spec_json_to_templates' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170828174622_add_spec_json_to_templates.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    before do
      db[:releases] << {
        name: 'hello'
      }
    end

    it 'allows you to save a spec-json' do
      DBSpecHelper.migrate(migration_file)
      expect(db[:templates].columns).to include(:spec_json)

      db[:templates] << {
        name: 'some-job',
        spec_json: '{"anything": "json"}',
        version: '23',
        blobstore_id: 'abc123',
        release_id: 1,
        package_names_json: '{}',
        sha1: 'shasha',
      }

      expect(db[:templates].first[:spec_json]).to eq '{"anything": "json"}'
    end

    it 'ensures that spec_json allows texts longer than 65535 character' do
      DBSpecHelper.migrate(migration_file)

      really_long_spec_json = 'a' * 65536
      db[:templates] << {
        name: 'some-job',
        spec_json: really_long_spec_json,
        version: '23',
        blobstore_id: 'abc123',
        release_id: 1,
        package_names_json: '{}',
        sha1: 'shasha',
      }

      expect(db[:templates].first[:spec_json].length).to eq(really_long_spec_json.length)
    end

    it 'backfills values from logs, templates, provides, consumes, and properties' do
      db[:templates] << {
        name: 'some-job',
        version: '23',
        blobstore_id: 'abc123',
        release_id: 1,
        package_names_json: '{"old":"packages"}',
        properties_json: '{"old":"properties"}',
        provides_json: '{"old":"provides"}',
        consumes_json: '{"old":"consumes"}',
        logs_json: '{"old":"logs"}',
        sha1: 'shasha',
      }

      DBSpecHelper.migrate(migration_file)

      expect(JSON.load(db[:templates].first[:spec_json])).to eq({
        'properties' => {'old' => 'properties'},
        'provides' => {'old' => 'provides'},
        'consumes' => {'old' => 'consumes'},
        'logs' => {'old' => 'logs'},
      })
    end
  end
end
