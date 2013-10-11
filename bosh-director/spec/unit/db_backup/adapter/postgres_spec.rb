require 'spec_helper'

describe Bosh::Director::DbBackup::Adapter::Postgres do
  describe 'export' do
    subject do
      described_class.new(
        'user' => 'user1',
        'password' => 'password1',
        'database' => 'database',
        'host' => 'host.com',
        'port' => 5432,
      )
    end

    let(:export_path) { 'my/awesome/path' }

    it 'exports the database to a file' do
      status = instance_double('Process::Status', success?: true)

      Open3.should_receive(:capture3).with(
        {'PGPASSWORD' => 'password1'},
        'pg_dump',
        '--host', 'host.com',
        '--port', '5432',
        '--username', 'user1',
        '--file', export_path,
        'database',
      ).and_return([nil, nil, status])

      expect(subject.export(export_path)).to eq(export_path)
    end

    it 'raises if it fails to export' do
      status = instance_double('Process::Status', success?: false, exitstatus: 5)

      Open3.stub(:capture3).and_return(['stdout', 'stderr', status])

      expect { subject.export(export_path) }.to raise_error(
        RuntimeError, "pg_dump exited 5, output: 'stdout', error: 'stderr'")
    end
  end
end
