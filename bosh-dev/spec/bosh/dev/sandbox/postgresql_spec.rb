require 'spec_helper'
require 'bosh/dev/sandbox/postgresql'
require 'tempfile'

module Bosh::Dev::Sandbox
  describe Postgresql do
    subject(:postgresql) { described_class.new(directory, runner) }

    let (:directory) { Dir.mktmpdir }
    let (:runner) { instance_double('Bosh::Core::Shell') }

    describe '#setup' do
      context 'when it succeeds' do
        it 'setups the initial database' do
          runner.should_receive(:run).with("initdb -D #{directory}")
          postgresql.setup
        end
      end

      context 'when it fails' do
        it 'raises an error' do
          runner.stub(:run).and_raise('fake error')
          expect { postgresql.setup }.to raise_error(RuntimeError, 'fake error')
        end
      end
    end

    describe '#run' do
      it 'start postgresql in a sandbox directory' do
        runner.should_receive(:run).with("pg_ctl start -D #{directory} -l #{directory}/pg.log")
        postgresql.run
      end
    end

    describe '#destroy' do
      it 'destroys the sandbox database' do
        runner.should_receive(:run).with("pg_ctl stop -m immediate -D #{directory}")
        postgresql.destroy
      end
    end

    describe '#dump' do
      it 'saves the postgresql db with pg_dump' do
        runner.should_receive(:run).with(
            "pg_dump --host #{directory} --format=custom --file=#{directory}/postgresql_backup postgres")
        postgresql.dump
      end
    end

    describe '#restore' do
      it 'restores the last dump with pg_load' do
        runner.should_receive(:run).with(
            "pg_restore --host #{directory} --clean --format=custom --file=#{directory}/postgresql_backup")
        postgresql.restore
      end
    end
  end
end
