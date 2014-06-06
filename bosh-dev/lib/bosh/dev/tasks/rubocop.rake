require 'rubocop/rake_task'

namespace :rubocop do
  desc 'Run RuboCop on new git files'
  Rubocop::RakeTask.new(:new) do |task|
    task.patterns = `git diff --cached --name-only --diff-filter=A -- *.rb`.split("\n")
  end

  desc 'Run RuboCop on all files'
  Rubocop::RakeTask.new(:all)
end

task rubocop: ['rubocop:all']
