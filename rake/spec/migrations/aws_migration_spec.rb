require 'spec_helper'
require "tmpdir"

describe "migrations:aws:new" do

  before do
    @tempdir= Dir.mktmpdir
    Bosh::Aws::MigrationHelper.stub!(:aws_migration_directory).and_return(@tempdir)
  end

  after do
    FileUtils.rm_rf(@tempdir)
  end


  it "errors without a name" do
    expect { subject.invoke }.to raise_error(SystemExit)
  end

  it "generates migration from the template with the correct timestamped filename" do
    name = "test_migration"
    timestamp = Time.now
    Time.stub(:new).and_return(timestamp)
    subject.invoke(name)

    timestamp_string = timestamp.getutc.strftime("%Y%m%d%H%M%S")
    File.exists?("#{@tempdir}/#{timestamp_string}_#{name}.rb").should be_true
    File.read("#{@tempdir}/#{timestamp_string}_#{name}.rb").should == <<-H
class TestMigration < Bosh::Aws::Migration
  def execute

  end
end
    H
  end
end