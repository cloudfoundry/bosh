require 'spec_helper'
require 'db_migrator'

module Bosh::Director
  describe 'DBMigrator' do
    subject(:db_migrator) { DBMigrator.new('FAKE_DB', {}, 0.01) }

    describe '#finished?' do
      before do
        allow(Sequel::TimestampMigrator).to receive(:new).and_return(instance_double(Sequel::TimestampMigrator))
      end

      it 'returns true if migration is already current' do
        allow(db_migrator).to receive(:current?).once.and_return(true)
        expect(db_migrator.finished?).to be(true)
      end

      it 'return true if migration is current after retrying' do
        allow(db_migrator).to receive(:current?).twice.and_return(false, true)
        expect(db_migrator.finished?).to be(true)
      end

      it 'returns false if migrations are never current' do
        allow(db_migrator).to receive(:current?).exactly(DBMigrator::MAX_MIGRATION_ATTEMPTS).times.and_return(false)
        expect(db_migrator.finished?).to be(false)
      end
    end
  end
end
