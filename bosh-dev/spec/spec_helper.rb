require 'rspec'
require 'rake'
require 'rspec/fire'

shared_context 'rake' do
  let(:rake) { Rake::Application.new }
  let(:task_name) { self.class.top_level_description }
  let(:task_path) { "rake/lib/tasks/#{task_name.split(':').first}" }
  let(:root) { File.expand_path('../../../../', File.dirname(__FILE__))}
  subject { rake[task_name] }

  def loaded_files_excluding_current_rake_file
    $".reject { |file| file == File.join(root, "#{task_path}.rake").to_s }
  end

  before do
    Rake.application = rake
    Rake.application.rake_require(task_path, [root], loaded_files_excluding_current_rake_file)

    Rake::Task.define_task(:environment)
  end
end

module RSpecRakeHelper
  def self.included(klass)
    klass.include_context('rake')
  end
end

SPEC_ROOT = File.dirname(__FILE__)

def spec_asset(name)
  File.join(SPEC_ROOT, 'assets', name)
end

RSpec.configure do |config|
  config.include(RSpec::Fire)
end
