require 'db_spec_helper'
require 'json'
require 'digest/sha1'

module Bosh::Director
  describe 'migration files' do
    let(:expected_digests) { JSON.load_file(DBSpecHelper.director_migrations_digest_file)}
    let(:actual_digests) do
      DBSpecHelper.get_migrations.each_with_object({}) do |migration, hash|
        hash[File.basename(migration, '.rb')] = Digest::SHA1.hexdigest(File.read(migration))
      end
    end

    it 'should have the same digest as the one that was previously recorded' do
      expect(expected_digests).to eq(actual_digests)
    end
  end
end
