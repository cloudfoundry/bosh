require 'spec_helper'

module Bosh::Director
  describe 'migration files' do
    let(:expected_digests) do
      [
        {
          filename: '20110209010747_initial.rb',
          sha1: 'c313f56a60615786b4c38ff72a1e2350e214e182',
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
        {
          filename: '20250618102610_migrate_ip_address_representation_from_integer_to_cidr_notation.rb',
          sha1: 'd46a761745beff513dd3dbb80ed80f97f15cea8e',
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
