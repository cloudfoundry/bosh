require 'rspec'

namespace :fly do
  desc 'Fly unit specs'
  task :unit do
    sh("RUBY_VERSION=2.1.6 fly #{concourse_target} execute -c ci/tasks/test-unit.yml -i bosh-src=$PWD")
  end

  desc 'Fly integration specs'
  task :integration do
    sh("DB=postgresql RUBY_VERSION=2.1.6 fly #{concourse_target} execute -p -c ci/tasks/test-integration.yml -i bosh-src=$PWD")
  end

  task :run, [:command] do |_, args|
    sh("RUBY_VERSION=2.1.6 COMMAND=\"#{args[:command]}\" fly #{concourse_target} execute -p -c ci/tasks/run.yml -i bosh-src=$PWD")
  end

  def concourse_target
    "-t #{ENV['CONCOURSE_TARGET']}" if ENV.has_key?('CONCOURSE_TARGET')
  end
end

desc 'Fly unit and integration specs'
task :fly => %w(fly:unit fly:integration)
