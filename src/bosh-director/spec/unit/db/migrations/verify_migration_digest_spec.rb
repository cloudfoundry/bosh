require 'db_migrator'
require 'json'
require 'digest/sha1'

module Bosh::Director
  describe 'migration files' do
    let(:expected_digests) do
      [
        {
          filename: '20110209010747_initial.rb',
          sha1: 'c9b5654ce0a4a5df4805a2acec301fc65e0fd310',
        },
        {
          filename: '20210902232124_add_blobstore_and_nats_shas_to_vms.rb',
          sha1: '7710e2c2c9589865382daaa456bd0e95b22ba3b6',
        },
        {
          filename: '20230103143246_add_permanent_nats_credentials_to_vms.rb',
          sha1: 'a01b24aa3891d6bb0eb4e4032553d4e9871a19e0',
        },
        {
          filename: '20240319204601_remove_dns_records_from_instances.rb',
          sha1: 'bb637d410772d09caabdb68a1126fbc9f9b4deec',
        },
      ]
    end

    let(:actual_digests) do
      Dir.glob(File.join(DBMigrator::MIGRATIONS_DIR, '*.rb')).map do |migration|
        {
          filename: File.basename(migration),
          sha1: Digest::SHA1.hexdigest(File.read(migration)),
        }
      end
    end

    it 'should have the same digest as the one that was previously recorded' do
      expect(expected_digests).to eq(actual_digests)
    end
  end
end
