require_relative '../../../../db_spec_helper'
require 'netaddr'

module Bosh::Director
  describe 'change address column in IP address to be a string to record IPv6 addresses' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170825141953_change_address_to_be_string_for_ipv6.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'allows instance_id to be null' do
      db[:ip_addresses] << {id: 1, instance_id: nil, address: NetAddr::CIDR.create("192.168.50.6").to_i}

      DBSpecHelper.migrate(migration_file)

      expect(db[:ip_addresses].first[:address_str]).to eq(NetAddr::CIDR.create("192.168.50.6").to_i.to_s)

      expect {
        db[:ip_addresses] << {id: 2, instance_id: nil, address_str: NetAddr::CIDR.create("192.168.50.6").to_i.to_s}
      }.to raise_error(Sequel::UniqueConstraintViolation, /ip_addresses.address/)

      expect {
        db[:ip_addresses] << {id: 3, instance_id: nil, address_str: nil}
      }.to raise_error(Sequel::NotNullConstraintViolation, /ip_addresses.address/)
    end
  end
end
