require 'spec_helper'
require 'bosh/dev/sandbox/mysql'

module Bosh::Dev::Sandbox
  describe Mysql do
    subject(:mysql) { described_class.new('fake_db_name',runner, logger, options) }
    let(:runner) { instance_double('Bosh::Core::Shell') }
    let(:options) do
      {
        username: 'my-username',
        password: 'my-password',
        host: 'db-host.com',
        port: 1234,
        ca_path: '/path-to-ca',
        tls_enabled: true
      }
    end

    describe 'defaults' do
      it 'has default values set' do
        db = described_class.new('fake_db_name',runner, logger)
        expect(db.username).to eq('root')
        expect(db.password).to eq('password')
        expect(db.host).to eq('127.0.0.1')
        expect(db.port).to eq(3306)
        expect(db.ca_path).to be_nil
        expect(db.tls_enabled).to eq(false)
      end
    end

    describe '#create_db' do
      it 'creates a database' do
        expect(runner).to receive(:run).with(
          %Q{mysql -h db-host.com -P 1234 --user=my-username --password=my-password -e 'create database `fake_db_name`;' > /dev/null 2>&1}, redact: ['my-password'])
        mysql.create_db
      end
    end

    describe '#drop_db' do
      it 'drops a database' do
        expect(runner).to receive(:run).with(
          %Q{mysql -h db-host.com -P 1234 --user=my-username --password=my-password -e 'drop database `fake_db_name`;' > /dev/null 2>&1}, redact: ['my-password'])
        mysql.drop_db
      end
    end

    describe '#connection_string' do
      it 'returns a configured string' do
        expect(subject.connection_string).to eq('mysql2://my-username:my-password@db-host.com:1234/fake_db_name')
      end
    end

    describe '#db_name' do
      it 'returns the configured database name' do
        expect(subject.db_name).to eq('fake_db_name')
      end
    end

    describe '#username' do
      it 'returns the configured username' do
        expect(subject.username).to eq('my-username')
      end
    end

    describe '#password' do
      it 'returns the configured password' do
        expect(subject.password).to eq('my-password')
      end
    end

    describe '#adapter' do
      it 'has the correct database adapter' do
        expect(subject.adapter).to eq('mysql2')
      end
    end

    describe '#port' do
      it 'has the correct port' do
        expect(subject.port).to eq(1234)
      end
    end

    describe '#ca_path' do
      it 'has the correct ca_path' do
        expect(subject.ca_path).to eq('/path-to-ca')
      end
    end

    describe '#tls_enabled' do
      it 'has the correct tls_enabled' do
        expect(subject.tls_enabled).to eq(true)
      end
    end
  end
end
