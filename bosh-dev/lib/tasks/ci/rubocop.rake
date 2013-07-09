task :rubocop => ['rubocop:all']

namespace :rubocop do
  desc 'Run rubocop on new git files'
  task :new do
    sh 'bundle exec rubocop `git diff --cached --name-only --diff-filter=A -- *.rb`'
  end

  task :all do
    sh 'bundle exec rubocop'
  end
end
