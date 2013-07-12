task rubocop: ['rubocop:all']

namespace :rubocop do
  desc 'Run rubocop on new git files'
  task :new do
    require 'rubocop'
    new_files = `git diff --cached --name-only --diff-filter=A -- *.rb`.split("\n")
    Rubocop::CLI.new.run(new_files)
  end

  task :all do
    require 'rubocop'
    Rubocop::CLI.new.run([])
  end
end
