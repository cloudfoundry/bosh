require 'spec_helper'
require 'bosh/dev/sandbox/postgresql'

module Bosh::Dev::Sandbox
  describe Postgresql do
    subject(:postgresql) { described_class.new('fake_db_name', logger, 9922, runner, 'my-pguser', 'my-pgpassword', 'host') }
    let(:runner) { instance_double('Bosh::Core::Shell') }

    describe 'defaults' do
      it 'has default values set' do
        db = described_class.new('fake_db_name', logger, runner)
        expect(db.username).to eq('postgres')
        expect(db.password).to eq('')
        expect(db.host).to eq('localhost')
      end
    end

    describe '#create_db' do
      it 'creates a database' do
        expect(runner).to receive(:run).with(
          %Q{PGPASSWORD=my-pgpassword psql -h host -p 9922 -U my-pguser -c 'create database "fake_db_name";' > /dev/null 2>&1})
        postgresql.create_db
      end
    end

    describe '#drop_db' do
      it 'drops a database' do
        expect(runner).to receive(:run).with(
          %Q{echo 'revoke connect on database "fake_db_name" from public; drop database "fake_db_name";' | PGPASSWORD=my-pgpassword psql -h host -p 9922 -U my-pguser})
        postgresql.drop_db
      end
    end

    describe '#connection_string' do
      it 'returns a configured string' do
        expect(subject.connection_string).to eq('postgres://my-pguser:my-pgpassword@host:9922/fake_db_name')
      end
    end

    describe '#db_name' do
      it 'returns the configured database name' do
        expect(subject.db_name).to eq('fake_db_name')
      end
    end

    describe '#username' do
      it 'returns the configured username' do
        expect(subject.username).to eq('my-pguser')
      end
    end

    describe '#password' do
      it 'returns nil' do
        expect(subject.password).to eq('my-pgpassword')
      end
    end

    describe '#adapter' do
      it 'has the correct database adapter' do
        expect(subject.adapter).to eq('postgres')
      end
    end

    describe '#port' do
      it 'has the correct port' do
        expect(subject.port).to eq(9922)
      end
    end
  end
end
