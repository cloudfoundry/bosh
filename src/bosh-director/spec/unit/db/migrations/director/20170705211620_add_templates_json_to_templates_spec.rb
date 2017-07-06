require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'add_templates_json_to_templates' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170705211620_add_templates_json_to_templates.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    it 'adds a templates_json column that allows long text' do
      DBSpecHelper.migrate(migration_file)
      db[:releases] << {id: 1, name: 'test_release'}

      large_json = "{\"key\": \"#{"foo" * 1000}\"}"
      template = {
        name: 'template_name_2',
        release_id: 1,
        version: 'abcd12345',
        blobstore_id: '1',
        package_names_json: '{}',
        sha1: "sha1",
        provides_json: '{}',
        consumes_json: '{}',
        templates_json: large_json,
      }
      db[:templates] << template

      refreshed = db[:templates].first
      template.keys.each do |key|
        expect(refreshed[key]).to eq(template[key])
      end
    end
  end
end
