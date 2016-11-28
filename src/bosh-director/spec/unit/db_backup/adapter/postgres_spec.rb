require 'spec_helper'

describe Bosh::Director::DbBackup::Adapter::Postgres do
  describe 'export' do
    subject { described_class.new(db_config) }

    let(:db_config) do
      {
        'user' => 'user1',
        'password' => 'password1',
        'database' => 'database',
        'host' => 'host.com',
        'port' => 5432,
      }
    end

    let(:export_path) { 'fake-export-path' }

    context 'when database is dumped successfully' do
      let(:status) { instance_double('Process::Status', success?: true) }

      context 'when the password is provided' do
        before { db_config['password'] = 'fake-password' }

        it 'exports the database to a file' do
          expect(Open3).to receive(:capture3).with(
            {'PGPASSWORD' => 'fake-password'},
            'pg_dump',
            '--host',     'host.com',
            '--port',     '5432',
            '--username', 'user1',
            '--file',     export_path,
            'database',
          ).and_return([nil, nil, status])

          expect(subject.export(export_path)).to eq(export_path)
        end
      end

      context 'when the password is not provided' do
        before { db_config.delete('password') }

        it 'exports the database to a file without using password with pg_dump' do
          expect(Open3).to receive(:capture3).with(
            {},
            'pg_dump',
            '--host',     'host.com',
            '--port',     '5432',
            '--username', 'user1',
            '--file',     export_path,
            'database',
          ).and_return([nil, nil, status])

          expect(subject.export(export_path)).to eq(export_path)
        end
      end
    end

    context 'when database is not dumped successfully' do
      let(:status) { instance_double('Process::Status', success?: false, exitstatus: 5) }

      it 'raises if it fails to export' do
        allow(Open3).to receive(:capture3).and_return(['stdout', 'stderr', status])
        expect { subject.export(export_path) }.to raise_error(
          RuntimeError, "pg_dump exited 5, output: 'stdout', error: 'stderr'")
      end
    end
  end
end
