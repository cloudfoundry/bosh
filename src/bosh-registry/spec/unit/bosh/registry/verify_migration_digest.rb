require 'spec_helper'
require 'json'
require 'digest/sha1'

module Bosh::Director
  describe 'Verify that each migration has not been modified' do
    it 'should match the digest in the digests file' do
      digests = JSON.parse(File.read(File.join(SpecHelper.registry_migrations_dir, 'migration_digests.json')))
      SpecHelper.get_migrations.each do | migration |

        digest = digests.fetch(File.basename(migration, ".rb"))

        expect(digest).to eq(Digest::SHA1.hexdigest(File.read(migration))), "A digest mismatch was detected in #{migration}"
      end
    end
  end
end
