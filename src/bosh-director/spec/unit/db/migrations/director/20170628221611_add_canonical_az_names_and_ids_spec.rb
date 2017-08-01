require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'add_canonical_az_names_and_ids' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170628221611_add_canonical_az_names_and_ids.rb' }
    let(:created_at_time) { Time.now.utc }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      DBSpecHelper.migrate(migration_file)
    end

    it 'does not allow duplicate entries' do
      db[:local_dns_encoded_azs] << {name: 'something'}

      expect {
        db[:local_dns_encoded_azs] << {name: 'something'}
      }.to raise_error Sequel::UniqueConstraintViolation
    end

    it 'does not allow null entries' do
      expect {
        db[:local_dns_encoded_azs] << {name: nil}
      }.to raise_error Sequel::NotNullConstraintViolation
    end
  end
end
