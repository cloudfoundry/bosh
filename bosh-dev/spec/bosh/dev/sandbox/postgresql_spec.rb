require 'spec_helper'
require 'logger'
require 'bosh/dev/sandbox/postgresql'

module Bosh::Dev::Sandbox
  describe Postgresql do
    subject(:postgresql) { described_class.new('fake_directory', 'fake_db_name', logger, runner) }
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
  end
end
