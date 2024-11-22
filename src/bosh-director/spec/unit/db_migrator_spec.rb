require 'spec_helper'

module Bosh::Director
  describe 'DBMigrator' do
    let(:db) { instance_double(Sequel::Database) }
    let(:db_migrator_options) { { target: 15, current: 10 } }
    let(:sequel_migrator_options) { { allow_missing_migration_files: true }.merge(db_migrator_options) }
    let(:retry_interval_override) { 0.01 }

    subject(:db_migrator) { DBMigrator.new(db, sequel_migrator_options, retry_interval_override) }

    describe '#initialize' do
      it 'sets the expected extensions' do
        expect(Sequel).to receive(:extension).with(:migration, :core_extensions)

        DBMigrator.new(db)
      end
    end

    describe '#current?' do
      it 'invokes Sequel::Migrator.is_current? with the expected args' do
        expect(Sequel::Migrator).to receive(:is_current?).with(db, DBMigrator::MIGRATIONS_DIR, sequel_migrator_options)
        db_migrator.current?
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
          sequel_migrator_options
        )

        db_migrator.migrate
      end
    end

    describe '#migrate' do
      it 'invokes Sequel::Migrator.run with the expected args' do
        expect(Sequel::Migrator).to receive(:run).with(db, DBMigrator::MIGRATIONS_DIR, sequel_migrator_options)
        db_migrator.migrate
      end
    end
  end
end
