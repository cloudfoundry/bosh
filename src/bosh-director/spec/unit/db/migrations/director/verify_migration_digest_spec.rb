require 'db_spec_helper'
require 'json'
require 'digest/sha1'

module Bosh::Director
  describe 'Verify that each migration has not been modified' do
    it 'should match the digest in the digests file' do
      digests = JSON.parse(File.read(File.join(DBSpecHelper.director_migrations_dir, '..', 'migration_digests.json')))
      DBSpecHelper.get_migrations.each do |migration|
        expected_digest = digests.fetch(File.basename(migration, '.rb'))

        actual_digest = ::Digest::SHA1.hexdigest(File.read(migration))
        expect(actual_digest).to(
          eq(expected_digest),
          "A digest mismatch was detected in #{migration}. Expected #{expected_digest}, Got #{actual_digest}",
        )
      end
    end
  end
end
