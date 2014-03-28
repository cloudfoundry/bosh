namespace :shipit do
  desc 'Pulls the most recent code, run all the tests and pushes the repo'
  task ruby: %w(git:pull rubocop spec git:push)

  desc 'Pulls the most recent code, run all Go related tests and pushes the repo'
  task go: %w(git:pull rubocop gospec git:push)
end

task :shipit => %w(shipit:ruby)
