require 'rubocop'

task rubocop: ['rubocop:all']

namespace :rubocop do
  desc 'Run rubocop on new git files'
  task :new do
    new_files = `git diff --cached --name-only --diff-filter=A -- *.rb`.split("\n")
    Rubocop::CLI.new.run(new_files)
  end

  task :all do
    Rubocop::CLI.new.run([])
  end
end
