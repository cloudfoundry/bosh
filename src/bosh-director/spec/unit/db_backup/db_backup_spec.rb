require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::DbBackup do
  describe 'create' do
    let(:db_config) {
      {
          'adapter' => adapter,
      }
    }

    context 'mysql2' do
      let(:adapter) { 'mysql2' }

      it 'returns a MySQL database backup object' do
        expect(described_class.create(db_config)).to be_a Bosh::Director::DbBackup::Adapter::Mysql2
      end
    end

    context 'postgresql' do
      let(:adapter) { 'postgres' }

      it 'returns a postgres database backup object' do
        expect(described_class.create(db_config)).to be_a Bosh::Director::DbBackup::Adapter::Postgres
      end
    end

    context 'adapter is not implemented' do
      let(:adapter) { 'foo' }

      it 'raises an error' do
        expect { described_class.create(db_config) }.to raise_error(Bosh::Director::DbBackup::Adapter::Error, "backup for database adapter foo (module Foo) is not implemented")
      end
    end

  end
end
