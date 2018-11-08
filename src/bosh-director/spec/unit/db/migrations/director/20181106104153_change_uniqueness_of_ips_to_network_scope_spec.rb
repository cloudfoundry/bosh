require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20181106104153_change_uniqueness_of_ips_to_network_scope.rb' do
    let(:db) { DBSpecHelper.db }

    before do
      DBSpecHelper.migrate_all_before(subject)
    end

    it 'has a unique index on address_str and and network name' do
      DBSpecHelper.migrate(subject)

      db[:ip_addresses] << { instance_id: nil, address_str: '10.0.0.1', network_name: 'network1' }

      expect do
        db[:ip_addresses] << { instance_id: nil, address_str: '10.0.0.1', network_name: 'network2' }
      end.not_to raise_error

      expect do
        db[:ip_addresses] << { instance_id: nil, address_str: '10.0.0.1', network_name: 'network1' }
      end.to raise_error(Sequel::UniqueConstraintViolation)
    end
  end
end
