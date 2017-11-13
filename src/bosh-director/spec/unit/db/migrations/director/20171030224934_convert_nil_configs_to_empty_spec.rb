require 'db_spec_helper'

module Bosh::Director
  describe '20171030224934_convert_nil_configs_to_empty' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20171030224934_convert_nil_configs_to_empty.rb' }
    let(:created_at) { Time.now }
    let(:content) { nil }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      db[:configs] << {
        type: 'anything',
        name: 'anything',
        content: content,
        created_at: created_at,
      }

      DBSpecHelper.migrate(migration_file)
    end

    context 'content is empty' do
      it 'converts to empty hash' do
        expect(db[:configs].all.first[:content]).to eq '--- {}'
      end
    end

    context 'content is YAML-nil' do
      let(:content) { "--- \n... \n" }

      it 'converts to empty hash' do
        expect(db[:configs].all.first[:content]).to eq '--- {}'
      end
    end

    context 'content is bad YAML syntax' do
      let(:content) { '{bad=yml' }

      it 'leaves it alone and continues' do
        expect(db[:configs].all.first[:content]).to eq '{bad=yml'
      end
    end

    it 'does not allow new configs with nil content' do
      expect {
        db[:configs] << {
          type: 'anything',
          name: 'anything',
          content: content,
          created_at: created_at,
        }
      }.to raise_error(Sequel::NotNullConstraintViolation)
    end
  end
end
