require 'spec_helper'

describe Bosh::Director::DbBackup::Adapter::Mysql2 do

  describe 'export' do
    let(:user) { 'user1' }
    let(:password) { 'password1' }
    let(:database) { 'database' }
    let(:host) { 'host.com' }
    let(:port) { 3306 }
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
      expect(Open3).to receive(:capture3).with(
            {'MYSQL_PWD' => password},
            'mysqldump',
            '--user', user,
            '--host', host,
            '--port', port.to_s,
            '--result-file', path,
            database).and_return([nil, nil, success_status])

        expect(subject.export(path)).to eq path
    end

    it 'raises if it fails to export' do
      allow(Open3).to receive(:capture3).and_return(['stdout string', 'a stderr message', errored_status])
      expect{subject.export(path)}.to raise_error(RuntimeError, "mysqldump exited 5, output: 'stdout string', error: 'a stderr message'")
    end
  end
end
