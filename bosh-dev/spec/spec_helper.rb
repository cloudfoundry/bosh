require "rspec"
require "rake"

shared_context "rake" do
  let(:rake) { Rake::Application.new }
  let(:task_name) { self.class.top_level_description }
  let(:task_path) { "rake/lib/tasks/#{task_name.split(":").first}" }
  let(:root) { File.expand_path("../../", File.dirname(__FILE__))}
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
    klass.include_context("rake")
  end
end

def spec_asset(name)
  File.expand_path("../assets/#{name}", __FILE__)
end