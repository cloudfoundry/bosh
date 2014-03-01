require 'spec_helper'
require 'logger'
require 'bosh/dev/sandbox/postgresql'

module Bosh::Dev::Sandbox
  describe Postgresql do
    subject(:postgresql) { described_class.new('fake_db_name', logger, runner) }
    let(:logger) { Logger.new(nil) }
    let(:runner) { instance_double('Bosh::Core::Shell') }

    describe '#create_db' do
      it 'creates a database' do
        runner.should_receive(:run).with(
          %Q{psql -U postgres -c 'create database "fake_db_name";' > /dev/null})
        postgresql.create_db
      end
    end

    describe '#drop_db' do
      it 'drops a database' do
        runner.should_receive(:run).with(
          %Q{psql -U postgres -c 'drop database "fake_db_name";' > /dev/null})
        postgresql.drop_db
      end
    end

    describe '#db_name' do
      it 'returns the configured database name' do
        expect(subject.db_name).to eq('fake_db_name')
      end
    end

    describe '#username' do
      it 'returns the configured username' do
        expect(subject.username).to eq('postgres')
      end
    end

    describe '#password' do
      it 'returns nil' do
        expect(subject.password).to eq('')
      end
    end

    describe '#adapter' do
      it 'has the correct database adapter' do
        expect(subject.adapter).to eq('postgres')
      end
    end

    describe '#port' do
      it 'has the correct port' do
        expect(subject.port).to eq(5432)
      end
    end
  end
end
