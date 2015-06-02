require 'rspec'

namespace :fly do
  desc 'Fly unit specs'
  task :unit do
    sh("fly execute -c ci/concourse/tasks/test-unit.yml -i bosh-src=$PWD")
  end

  desc 'Fly integration specs'
  task :integration do
    sh("fly execute -p -c ci/concourse/tasks/test-integration.yml -i bosh-src=$PWD")
  end
end

desc 'Fly unit and integration specs'
task :fly => %w(fly:unit fly:integration)
