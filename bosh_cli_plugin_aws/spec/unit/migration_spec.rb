require 'spec_helper'

class DummyMigration < Bosh::Aws::Migration
  def execute
    s3.create_bucket(self.class.name)
  end
end

describe Bosh::Aws::Migrator do

  let(:config) { {'aws' => {}, 'name' => "deployment-name"} }
  let(:subject) { described_class.new(config) }
  let(:mock_s3) { mock("Bosh::Aws::S3").as_null_object }

  before(:all) do
    @tempdir = Dir.mktmpdir
  end

  after(:all) do
    FileUtils.rm_rf(@tempdir)
  end

  before do
    @time = Time.now
    Time.stub(:new) { @time }

    Bosh::Aws::MigrationHelper.stub!(:aws_migration_directory).and_return(@tempdir)

    Bosh::Aws::S3.stub(:new).and_return(mock_s3)
    mock_s3.stub(:fetch_object_contents).and_return(nil)
  end

  it "should not create an s3 bucket if there is one already" do
    mock_s3.should_receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(true)
    mock_s3.should_not_receive(:create_bucket)

    subject.migrate
  end

  it "should create an s3 bucket if one isn't there" do
    mock_s3.should_receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(false)
    mock_s3.should_receive(:create_bucket).with('deployment-name-bosh-artifacts')

    subject.migrate
  end

  context "with migrations" do

    before do
      @expected_migrations = []
      10.times do |i|
        timestamp = Bosh::Aws::MigrationHelper.timestamp
        name = "test_#{i}"

        filename = "#{@tempdir}/#{timestamp}_#{name}.rb"
        File.open(filename, 'w+') do |f|
          migration_text = Bosh::Aws::MigrationHelper.merge_migration_template(name)
          migration_text.gsub!("Bosh::Aws::Migration","DummyMigration")
          migration_text.gsub!("execute","execute_not_used")
          f.write(migration_text)
        end

        @expected_migrations << Bosh::Aws::MigrationProxy.new(name, timestamp.to_i)
        @time += 1 #Time marches on
      end
    end

    it 'should create a list of known migrations' do
      subject.migrations.should == @expected_migrations
    end

    context "#migrate" do
      it "should run all the migrations if it has never been run before" do
        mock_s3.should_receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(true)

        ordered_expectations = mock_s3.should_receive(:create_bucket).ordered

        10.times do |i|
          ordered_expectations.with("Test#{i}")
        end

        subject.migrate
      end

      it "should run the migrations that has never been run before" do
        mock_s3.should_receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(true)
        mock_s3.
            should_receive(:fetch_object_contents).
            with('deployment-name-bosh-artifacts', "aws_migrations/migrations.yaml").
            and_return(YAML.dump(@expected_migrations[0..5].collect{|m|m.to_hash}))

        ordered_expectations = mock_s3.should_receive(:create_bucket).ordered
        (6..9).each do |i|
          ordered_expectations.with("Test#{i}")
        end

        subject.migrate
      end

      it "should not run migrations that has already been run" do
        mock_s3.should_receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(true)
        mock_s3.
            should_receive(:fetch_object_contents).
            with('deployment-name-bosh-artifacts', "aws_migrations/migrations.yaml").
            and_return(YAML.dump(@expected_migrations.collect{|m|m.to_hash}))

        mock_s3.should_not_receive(:create_bucket)

        subject.migrate
      end
    end

    context "#needs_migration?" do

      before do
        mock_s3.should_receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(true)
      end

      it 'should need a migration if S3 file is missing' do
        subject.needs_migration?.should be_true
      end

      it "should need a migration if S3 file has migrations, but not all" do
        mock_s3.
            should_receive(:fetch_object_contents).
            with('deployment-name-bosh-artifacts', "aws_migrations/migrations.yaml").
            and_return(YAML.dump(@expected_migrations[0..5].collect{|m|m.to_hash}))

        subject.needs_migration?.should be_true
      end

      it 'should not need a migration if S3 file has all the migrations' do
        mock_s3.
            should_receive(:fetch_object_contents).
            with('deployment-name-bosh-artifacts', "aws_migrations/migrations.yaml").
            and_return(YAML.dump(@expected_migrations.collect{|m|m.to_hash}))

        subject.needs_migration?.should be_false
      end
    end
  end
end