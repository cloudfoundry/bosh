require 'spec_helper'

describe Bosh::Director::DbBackup::Adapter::Postgres do

  describe 'export' do
    let(:user) { 'user1' }
    let(:password) { 'password1' }
    let(:database) { 'database' }
    let(:host) { 'host.com' }
    let(:port) { 5432 }
    let(:path) { 'my/awesome/path' }
    let(:success_status) { double('Status', success?: true) }
    let(:errored_status) { double('Status', success?: false, exitstatus: 5) }
    subject {
      described_class.new(
          {
              'user' => user,
              'password' => password,
              'database' => database,
              'host' => host,
              'port' => port,
          })
    }

    it 'exports the database to a file' do
      Open3.should_receive(:capture3).with({'PGPASSWORD' => password},
                                           'pg_dump',
                                           '--host', host,
                                           '--port', port.to_s,
                                           '--username', user,
                                           '--file', path,
                                           database).and_return([nil, nil, success_status])
      expect(subject.export(path)).to eq path
    end

    it 'raises if it fails to export' do
      Open3.stub(:capture3).and_return(['stdout string', 'a stderr message', errored_status])
      expect{subject.export(path)}.to raise_error(RuntimeError, "pg_dump exited 5, output: 'stdout string', error: 'a stderr message'")
    end
  end

end
