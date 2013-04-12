require 'spec_helper'
require "tmpdir"

describe "migrations:aws:new" do
  let(:name) { "cool_migration" }
  let(:class_name) { "CoolMigration" }
  let(:timestamp) { Time.now }
  let(:timestamp_string) {timestamp.getutc.strftime("%Y%m%d%H%M%S") }

  before do
    Time.stub(:new).and_return(timestamp)

    @tempdir= Dir.mktmpdir
    Bosh::Aws::MigrationHelper.stub!(:aws_migration_directory).and_return(@tempdir)
    Bosh::Aws::MigrationHelper.stub!(:aws_spec_migration_directory).and_return(@tempdir)
  end

  after do
    FileUtils.rm_rf(@tempdir)
  end

  it "errors without a name" do
    expect { subject.invoke }.to raise_error(SystemExit)
  end

  it "generates migration from the template with the correct timestamped filename" do
    subject.invoke(name)

    File.exists?("#{@tempdir}/#{timestamp_string}_#{name}.rb").should be_true
    File.read("#{@tempdir}/#{timestamp_string}_#{name}.rb").should == <<-H
class CoolMigration < Bosh::Aws::Migration
  def execute

  end
end
    H
  end

  it "generates the spec template for the migration" do
    subject.invoke(name)

    File.exists?("#{@tempdir}/#{timestamp_string}_#{name}_spec.rb").should be_true
    File.read("#{@tempdir}/#{timestamp_string}_#{name}_spec.rb").should == <<-H
require 'spec_helper'
require '#{timestamp_string}_#{name}'

describe CoolMigration do
  include MigrationSpecHelper

  subject { described_class.new(config, '')}

  it "migrates your cloud" do
    expect { subject.execute }.to_not raise_error
  end
end
    H
  end
end