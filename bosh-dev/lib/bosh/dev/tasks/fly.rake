require 'rspec'

namespace :fly do
  desc 'Fly unit specs'
  task :unit do
    sh("GIT_BRANCH=#{git_branch} fly execute -c ci/concourse/tasks/test-unit.yml -i bosh-src=$PWD")
  end

  desc 'Fly integration specs'
  task :integration do
    sh("GIT_BRANCH=#{git_branch} fly execute -p -c ci/concourse/tasks/test-integration.yml -i bosh-src=$PWD")
  end

  def git_branch
    @git_branch ||= (ENV['GIT_BRANCH'] || `cat .git/HEAD`.split('/').last)
  end
end

desc 'Fly unit and integration specs'
task :fly => %w(fly:unit fly:integration)
