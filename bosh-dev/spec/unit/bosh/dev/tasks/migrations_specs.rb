require 'spec_helper'
require 'tmpdir'

describe 'migrations:aws:new' do
  let(:rake) { Rake::Application.new }
  let(:task_path) { 'rake/lib/tasks/migrations' }
  let(:root) { File.expand_path('../../../../', File.dirname(__FILE__)) }
  let(:name) { 'cool_migration' }
  let(:class_name) { 'CoolMigration' }
  let(:timestamp) { Time.now }
  let(:timestamp_string) { timestamp.getutc.strftime('%Y%m%d%H%M%S') }

  subject { rake['migrations:aws:new'] }

  def loaded_files_excluding_current_rake_file
    $LOADED_FEATURES.reject { |file| file == File.join(root, "#{task_path}.rake").to_s }
  end

  before do
    Rake.application = rake
    Rake.application.rake_require(task_path, [root], loaded_files_excluding_current_rake_file)

    Rake::Task.define_task(:environment)
    allow(Time).to receive(:new).and_return(timestamp)

    @tempdir = Dir.mktmpdir
    allow(Bosh::AwsCliPlugin::MigrationHelper).to receive(:aws_migration_directory).and_return(@tempdir)
    allow(Bosh::AwsCliPlugin::MigrationHelper).to receive(:aws_spec_migration_directory).and_return(@tempdir)
  end

  after do
    FileUtils.rm_rf(@tempdir)
  end

  it 'errors without a name' do
    expect { subject.invoke }.to raise_error(SystemExit)
  end

  it 'generates migration from the template with the correct timestamped filename' do
    subject.invoke(name)

    expect(File.exists?("#{@tempdir}/#{timestamp_string}_#{name}.rb")).to be(true)
    expect(File.read("#{@tempdir}/#{timestamp_string}_#{name}.rb")).to eq <<-H
class CoolMigration < Bosh::AwsCliPlugin::Migration
  def execute

  end
end
    H
  end

  it 'generates the spec template for the migration' do
    subject.invoke(name)

    expect(File.exists?("#{@tempdir}/#{timestamp_string}_#{name}_spec.rb")).to be(true)
    expect(File.read("#{@tempdir}/#{timestamp_string}_#{name}_spec.rb")).to eq <<-H
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
