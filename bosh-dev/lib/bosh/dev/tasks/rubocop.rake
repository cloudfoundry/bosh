require 'rubocop/rake_task'

namespace :rubocop do
  desc 'Run RuboCop on new git files'
  RuboCop::RakeTask.new(:new) do |task|
    task.patterns = `git diff --cached --name-only --diff-filter=A -- *.rb`.split("\n")
    task.options << '--lint'
  end

  desc 'Run RuboCop on all files'
  RuboCop::RakeTask.new(:all) do |task|
    task.options << '--lint'
  end
end

task rubocop: ['rubocop:all']
