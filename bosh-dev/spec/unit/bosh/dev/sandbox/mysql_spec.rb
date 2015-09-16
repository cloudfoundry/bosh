require 'spec_helper'
require 'bosh/dev/sandbox/mysql'

module Bosh::Dev::Sandbox
  describe Mysql do
    subject(:mysql) { described_class.new('fake_db_name', logger, runner, 'root', 'password') }
    let(:runner) { instance_double('Bosh::Core::Shell') }

    describe '#create_db' do
      it 'creates a database' do
        expect(runner).to receive(:run).with(
          %Q{mysql --user=root --password=password -e 'create database `fake_db_name`;' > /dev/null 2>&1})
        mysql.create_db
      end
    end

    describe '#drop_db' do
      it 'drops a database' do
        expect(runner).to receive(:run).with(
          %Q{mysql --user=root --password=password -e 'drop database `fake_db_name`;' > /dev/null 2>&1})
        mysql.drop_db
      end
    end

    describe '#db_name' do
      it 'returns the configured database name' do
        expect(subject.db_name).to eq('fake_db_name')
      end
    end

    describe '#username' do
      it 'returns the configured username' do
        expect(subject.username).to eq('root')
      end
    end

    describe '#password' do
      it 'returns the configured password' do
        expect(subject.password).to eq('password')
      end
    end

    describe '#adapter' do
      it 'has the correct database adapter' do
        expect(subject.adapter).to eq('mysql2')
      end
    end

    describe '#port' do
      it 'has the correct port' do
        expect(subject.port).to eq(3306)
      end
    end
  end
end
