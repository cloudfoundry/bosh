require 'spec_helper'

describe Bosh::Director::DbBackup::Adapter::Mysql2 do

  let(:command_runner) { double('command runner') }

  describe 'export' do
    let(:user) { 'user1' }
    let(:password) { 'password1' }
    let(:database) { 'database' }
    let(:host) { 'host.com' }
    let(:port) { 3306 }

    it 'exports the database to a file' do
      Dir::Tmpname.create('export') do |path|

        db_backup = described_class.new(
            {
                'user' => user,
                'password' => password,
                'database' => database,
                'host' => host,
                'port' => port,
            })
        db_backup.command_runner = command_runner

        command_runner.should_receive(:sh).with(
            "LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/var/vcap/packages/mysql/lib/mysql /var/vcap/packages/mysql/bin/mysqldump --user=#{user} --password=#{password} --host=#{host} --port=#{port} #{database} > #{path}")

        expect(db_backup.export(path)).to eq path
      end
    end
  end

end
