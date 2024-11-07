require 'spec_helper'
require 'db_migrator'

module Bosh::Director
  describe 'DBMigrator' do
    let(:db) { instance_double(Sequel::Database) }
    let(:options) { { target: 15, current: 10 } }
    let(:retry_interval_override) { 0.01 }

    subject(:db_migrator) { DBMigrator.new(db, options, retry_interval_override) }

    describe '#initialize' do
      it 'sets the expected extensions' do
        expect(Sequel).to receive(:extension).with(:migration, :core_extensions)

        DBMigrator.new(db)
      end
    end

    describe '#ensure_migrated!' do
      it 'does not raise an error if already current' do
        allow(Sequel::Migrator).to receive(:is_current?).once.and_return(true)
        expect {
          db_migrator.ensure_migrated!
        }.not_to raise_error
      end

      it 'does not raise an error if migration is current after retrying' do
        allow(Sequel::Migrator).to receive(:is_current?).twice.and_return(false, true)
        expect {
          db_migrator.ensure_migrated!
        }.not_to raise_error
      end

      it 'raise an error if migrations are never current' do
        allow(Sequel::Migrator).to receive(:is_current?).exactly(DBMigrator::MAX_MIGRATION_ATTEMPTS).times.and_return(false)
        expect {
          db_migrator.ensure_migrated!
        }.to raise_error(DBMigrator::MigrationsNotCurrentError,
                         "Migrations not current after #{DBMigrator::MAX_MIGRATION_ATTEMPTS} retries")
      end
    end

    describe '#finished?' do
      it 'returns true if migration is already current' do
        allow(Sequel::Migrator).to receive(:is_current?).once.and_return(true)
        expect(db_migrator.finished?).to be(true)
      end

      it 'return true if migration is current after retrying' do
        allow(Sequel::Migrator).to receive(:is_current?).twice.and_return(false, true)
        expect(db_migrator.finished?).to be(true)
      end

      it 'returns false if migrations are never current' do
        allow(Sequel::Migrator).to receive(:is_current?).exactly(DBMigrator::MAX_MIGRATION_ATTEMPTS).times.and_return(false)
        expect(db_migrator.finished?).to be(false)
      end
    end

    describe '#finished?' do
      it 'calls Sequel::Migrator#migrate with the expected arguments' do
        allow(Sequel::Migrator).to receive(:run).with(
          db,
          DBMigrator::MIGRATIONS_DIR,
          options
        )

        db_migrator.migrate
      end
    end
  end
end
