require 'spec_helper'
require 'json'
require 'tempfile'

module Bosh::Director
  describe 'validate mysql database' do
    let(:db) { Bosh::Director::Config.db }
    let(:committed_schema_file) { File.expand_path('../../../../../db/schema.dump', __FILE__) }
    let(:tmp_schema_file) { Tempfile.new('generated_schema') }

    it 'should match the schema that is currently checked in' do
      require_relative '../../../../lib/bosh/director/models'
      db.dump_schema_cache(tmp_schema_file)
      generated_contents = File.read(tmp_schema_file)
      committed_contents = File.read(committed_schema_file)

      generated_schema = JSON.load(generated_contents)
      committed_schema = JSON.load(committed_contents)

      expect(generated_schema).to eq(committed_schema)

      # Run `be rake migrations:schema:dump` to update `schema.dump`
      # Re-run this test. If it passes, commit updated `schema.dump` file
    end

    context 'schema dump exists' do
      it 'loads schemas' do
        db.load_schema_cache?(committed_schema_file)
        expect(db.schemas.length).to_not eq(0)
      end
    end
  end
end
