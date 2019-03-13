require 'spec_helper'
require 'db_migrator'

module Bosh::Director
  describe 'DBMigrator' do
    subject(:migrator) { DBMigrator.new('db', 'test', {}, 0.01) }

    describe '#finished?' do
      it 'returns true if migration is already current' do
        allow(migrator).to receive(:current?).once.and_return(true)
        expect(migrator.finished?).to be(true)
      end

      it 'return true if migration is current after retrying' do
        allow(migrator).to receive(:current?).twice.and_return(false, true)
        expect(migrator.finished?).to be(true)
      end

      it 'returns false if migrations are never current' do
        allow(migrator).to receive(:current?).exactly(DBMigrator::MAX_MIGRATION_ATTEMPTS).times.and_return(false)
        expect(migrator.finished?).to be(false)
      end
    end
  end
end
