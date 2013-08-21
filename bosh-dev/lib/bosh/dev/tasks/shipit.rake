desc 'Pulls the most recent code, run all the tests and pushes the repo'
task shipit: %w[git:pull rubocop spec git:push]
