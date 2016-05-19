require 'spec_helper'
require 'bosh/dev/sandbox/sqlite'

module Bosh::Dev::Sandbox
  describe Sqlite do
    subject(:subject) { described_class.new('fake_db_name', logger, runner) }
    let(:runner) { instance_double('Bosh::Core::Shell') }

    describe '#create_db' do
      it 'creates a database' do
        subject.create_db
      end
    end

    describe '#drop_db' do
      it 'drops a database' do
        expect(runner).to receive(:run).with(
          %Q{rm fake_db_name})
        subject.drop_db
      end
    end

    describe '#connection_string' do
      it 'returns a configured string' do
        expect(subject.connection_string).to eq('sqlite://fake_db_name')
      end
    end

    describe '#db_name' do
      it 'returns the configured database name' do
        expect(subject.db_name).to eq('fake_db_name')
      end
    end

    describe '#username' do
      it 'returns the configured username' do
        expect(subject.username).to be_nil
      end
    end

    describe '#password' do
      it 'returns nil' do
        expect(subject.password).to be_nil
      end
    end

    describe '#adapter' do
      it 'has the correct database adapter' do
        expect(subject.adapter).to eq('sqlite')
      end
    end

    describe '#port' do
      it 'has the correct port' do
        expect(subject.port).to be_nil
      end
    end
  end
end
