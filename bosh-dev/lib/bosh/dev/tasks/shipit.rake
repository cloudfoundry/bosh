desc 'Pulls the most recent code, run all the tests and pushes the repo'
task shipit: %w[build_check git:pull rubocop spec git:push]
