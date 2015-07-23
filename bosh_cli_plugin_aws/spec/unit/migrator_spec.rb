require 'spec_helper'

class DummyMigration < Bosh::AwsCliPlugin::Migration
  def execute
    s3.create_bucket(self.class.name)
  end
end

describe Bosh::AwsCliPlugin::Migrator do

  let(:config) { {'aws' => {}, 'name' => 'deployment-name', 'vpc' => {'domain' => 'deployment-name.foo.com'}} }
  let(:subject) { described_class.new(config) }
  let(:mock_s3) { double("Bosh::AwsCliPlugin::S3").as_null_object }

  after do
    FileUtils.rm_rf(@tempdir)
  end

  before do
    @tempdir = Dir.mktmpdir

    @time = Time.now
    allow(Time).to receive(:new) { @time }

    allow(Bosh::AwsCliPlugin::MigrationHelper).to receive(:aws_migration_directory).and_return(@tempdir)

    allow(Bosh::AwsCliPlugin::S3).to receive(:new).and_return(mock_s3)
    allow(mock_s3).to receive(:fetch_object_contents).and_return(nil)
    allow(mock_s3).to receive(:upload_to_bucket).and_return(nil)
  end

  it "should not create the old s3 bucket if there is one already" do
    expect(mock_s3).to receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(true)
    expect(mock_s3).not_to receive(:create_bucket)

    subject.migrate
  end

  it "should not create the new s3 bucket if there is one already" do
    expect(mock_s3).to receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(false)
    expect(mock_s3).to receive(:bucket_exists?).with('deployment-name-foo-com-bosh-artifacts').and_return(true)
    expect(mock_s3).not_to receive(:create_bucket)

    subject.migrate
  end

  it "should create an s3 bucket if one isn't there" do
    expect(mock_s3).to receive(:bucket_exists?).exactly(3).times.with('deployment-name-bosh-artifacts').and_return(false)
    expect(mock_s3).to receive(:bucket_exists?).with('deployment-name-foo-com-bosh-artifacts').and_return(false)
    expect(mock_s3).to receive(:create_bucket).with('deployment-name-foo-com-bosh-artifacts')

    subject.migrate
  end

  context "with migrations" do

    before do
      @expected_migrations = []
      10.times do |i|
        name = "test_#{i}"

        template = Bosh::AwsCliPlugin::MigrationHelper::Template.new(name)

        filename = "#{@tempdir}/#{template.file_prefix}.rb"
        File.open(filename, 'w+') do |f|
          migration_text = template.render
          migration_text.gsub!("Bosh::AwsCliPlugin::Migration","DummyMigration")
          migration_text.gsub!("execute","execute_not_used")
          f.write(migration_text)
        end

        @expected_migrations << Bosh::AwsCliPlugin::MigrationProxy.new(name, template.timestamp_string)
        @time += 1 #Time marches on
      end
    end

    it 'should create a list of known migrations' do
      expect(subject.migrations).to eq(@expected_migrations)
    end

    context "migrate_version" do
      let(:migration_to_run) { @expected_migrations[4] }

      it "should run only the specified version if it has never been run before" do
        expect(mock_s3).to receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(true)

        expect(mock_s3).to receive(:create_bucket).with("Test4")

        subject.migrate_version(migration_to_run.version)
      end

      it "should only write the specific version to the versions file" do
        expect(mock_s3).to receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(true)

        allow(mock_s3).to receive(:create_bucket)

        expect(mock_s3).to receive(:upload_to_bucket)
        .with('deployment-name-bosh-artifacts', "aws_migrations/migrations.yaml",
              YAML.dump([migration_to_run.to_hash]))

        subject.migrate_version(migration_to_run.version)
      end

      it "should not run if the specified version has been run before" do
        expect(mock_s3).to receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(true)
        expect(mock_s3).
            to receive(:fetch_object_contents).
            with('deployment-name-bosh-artifacts', "aws_migrations/migrations.yaml").
            and_return(YAML.dump(@expected_migrations.collect{|m|m.to_hash}))

        expect(mock_s3).not_to receive(:create_bucket)

        subject.migrate_version(@expected_migrations[4].version)
      end
    end

    context "#migrate" do
      it "should run all the migrations if it has never been run before" do
        expect(mock_s3).to receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(true)

        ordered_expectations = expect(mock_s3).to receive(:create_bucket).ordered

        10.times do |i|
          ordered_expectations.with("Test#{i}")
        end

        subject.migrate
      end

      it "should run the migrations that has never been run before" do
        expect(mock_s3).to receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(true)
        expect(mock_s3).
            to receive(:fetch_object_contents).
            with('deployment-name-bosh-artifacts', "aws_migrations/migrations.yaml").
            and_return(YAML.dump(@expected_migrations[0..5].collect{|m|m.to_hash}))

        ordered_expectations = expect(mock_s3).to receive(:create_bucket).ordered
        (6..9).each do |i|
          ordered_expectations.with("Test#{i}")
        end

        subject.migrate
      end

      it "should not run migrations that has already been run" do
        expect(mock_s3).to receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(true)
        expect(mock_s3).
            to receive(:fetch_object_contents).
            with('deployment-name-bosh-artifacts', "aws_migrations/migrations.yaml").
            and_return(YAML.dump(@expected_migrations.collect{|m|m.to_hash}))

        expect(mock_s3).not_to receive(:create_bucket)

        subject.migrate
      end

      it "should write the migrations in the S3 bucket after each migration" do
        expect(mock_s3).to receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(true)

        allow(mock_s3).to receive(:create_bucket)
        successful_migrations = []
        @expected_migrations.each do |migration|

          successful_migrations << migration
          expect(mock_s3).to receive(:upload_to_bucket)
             .with('deployment-name-bosh-artifacts', "aws_migrations/migrations.yaml",
                   YAML.dump(successful_migrations.collect{|m|m.to_hash}))
        end
        subject.migrate
      end
    end

    context "#needs_migration?" do

      before do
        expect(mock_s3).to receive(:bucket_exists?).with('deployment-name-bosh-artifacts').and_return(true)
      end

      it 'should need a migration if S3 file is missing' do
        expect(subject.needs_migration?).to be(true)
      end

      it "should need a migration if S3 file has migrations, but not all" do
        expect(mock_s3).
            to receive(:fetch_object_contents).
            with('deployment-name-bosh-artifacts', "aws_migrations/migrations.yaml").
            and_return(YAML.dump(@expected_migrations[0..5].collect{|m|m.to_hash}))

        expect(subject.needs_migration?).to be(true)
      end

      it 'should not need a migration if S3 file has all the migrations' do
        expect(mock_s3).
            to receive(:fetch_object_contents).
            with('deployment-name-bosh-artifacts', "aws_migrations/migrations.yaml").
            and_return(YAML.dump(@expected_migrations.collect{|m|m.to_hash}))

        expect(subject.needs_migration?).to be(false)
      end
    end
  end
end
