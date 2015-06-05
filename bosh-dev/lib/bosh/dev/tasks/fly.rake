require 'rspec'

namespace :fly do
  desc 'Fly unit specs'
  task :unit do
    perform do
      sh("fly execute -c ci/concourse/tasks/test-unit.yml -i bosh-src=$PWD")
    end
  end

  desc 'Fly integration specs'
  task :integration do
    perform do
      sh("fly execute -p -c ci/concourse/tasks/test-integration.yml -i bosh-src=$PWD")
    end
  end

  def git_branch
    @git_branch ||= (ENV['GIT_BRANCH'] || `cat .git/HEAD`.split('/').last).strip
  end

  def perform
    File.open('.fly_exec', 'w') do |f|
      f.puts("export GIT_BRANCH=#{git_branch}")
      f.puts('export TERM=xterm-256color')
      f.puts('export DB=postgresql')
      f.puts('export RUBY_VERSION=2.1.6')
    end
    yield
  ensure
    File.delete('.fly_exec')
  end
end

desc 'Fly unit and integration specs'
task :fly => %w(fly:unit fly:integration)
