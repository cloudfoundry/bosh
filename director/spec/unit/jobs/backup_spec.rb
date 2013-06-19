require 'spec_helper'

describe Bosh::Director::Jobs::Backup do
  let(:tar_gzipper) { double('tar gzipper') }
  let(:backup_bosh) { described_class.new("/var/vcap/store/director", tar_gzipper: tar_gzipper) }

  let(:log_directory) { "/var/vcap/sys/log" }
  let(:log_destination_path) { "/var/vcap/store/director/logs.tgz" }

  let(:task_log_directory) { "/var/vcap/store/director/tasks" }
  let(:task_log_destination_path) { "/var/vcap/store/director/task_logs.tgz" }

  let(:database_dump_path) { "/var/vcap/store/director/director_db.sql" }

  let(:combined_path) { "/var/vcap/store/director/backup.tgz" }

  it "zips up the logs" do
    tar_gzipper.should_receive(:compress).with(log_directory, log_destination_path)

    backup_bosh.backup_logs
  end

  it "zips up the task logs" do
    tar_gzipper.should_receive(:compress).with(task_log_directory, task_log_destination_path)

    backup_bosh.backup_task_logs
  end

  it "backs up the database" do
    db_config = double('db_config')
    BD::Config.stub(db_config: db_config)

    db_adapter = double('db adapter')
    db_adapter_creator = double('db adapter creator')
    backup_bosh.db_adapter_creator = db_adapter_creator
    db_adapter_creator.should_receive(:create).with(db_config).and_return(db_adapter)
    db_adapter.should_receive(:export).with(database_dump_path)

    backup_bosh.backup_database
  end

  it "combines the tarballs" do
    db_adapter = double('db adapter')
    db_adapter_creator = double('db adapter creator')
    backup_bosh.db_adapter_creator = db_adapter_creator
    db_adapter_creator.stub(create: db_adapter)
    db_adapter.stub(:export)

    tar_gzipper.should_receive(:compress).with(log_directory, log_destination_path)
    tar_gzipper.should_receive(:compress).with(task_log_directory, task_log_destination_path)
    tar_gzipper.should_receive(:compress).with([log_destination_path, task_log_destination_path, database_dump_path],
                                               combined_path)

    backup_bosh.perform
  end

  it "returns the destination of the logs" do
    db_adapter = double('db adapter')
    db_adapter_creator = double('db adapter creator')
    backup_bosh.db_adapter_creator = db_adapter_creator
    db_adapter_creator.stub(create: db_adapter)
    db_adapter.stub(:export)

    tar_gzipper.stub(:compress)

    expect(backup_bosh.perform).to eq 'Backup created at /var/vcap/store/director/backup.tgz'
  end
end