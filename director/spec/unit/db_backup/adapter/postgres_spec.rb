require 'spec_helper'

describe Bosh::Director::DbBackup::Adapter::Postgres do

  let(:command_runner) { double('command runner') }

  describe 'export' do
    let(:user) { 'user1' }
    let(:password) { 'password1' }
    let(:database) { 'database' }
    let(:host) { 'host.com' }
    let(:port) { 5432 }

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
            "PGPASSWORD=#{password} /var/vcap/packages/postgres/bin/pg_dump --host #{host} --port #{port} --username=#{user} #{database} > #{path}")

        expect(db_backup.export(path)).to eq path
      end
    end
  end

end
