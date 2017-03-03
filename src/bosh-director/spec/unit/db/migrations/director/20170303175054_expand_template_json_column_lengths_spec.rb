require 'db_spec_helper'

module Bosh::Director
  describe '20170303175054_expand_template_json_column_lengths' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170303175054_expand_template_json_column_lengths.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)

    end

    it 'expands the column lengths' do
      db[:releases] << {id: 1, name: 'test_release'}
      template_1 = {
          name: 'template_name',
          release_id: 1,
          version: 'abcd1234',
          blobstore_id: '1',
          package_names_json: '{}',
          sha1: "sha1",
          provides_json: '{"provides": "json"}',
          consumes_json: '{"consumes": "json"}'
      }
      db[:templates] << template_1

      DBSpecHelper.migrate(migration_file)

      refreshed = db[:templates].first
      template_1.keys.each do |key|
        expect(refreshed[key]).to eq(template_1[key])
      end

      large_json = "{\"key\": \"#{"foo" * 1000}\"}"
      db[:templates] << {
          name: 'template_name_2',
          release_id: 1,
          version: 'abcd12345',
          blobstore_id: '1',
          package_names_json: '{}',
          sha1: "sha1",
          provides_json: large_json,
          consumes_json: large_json
      }
    end
  end
end
