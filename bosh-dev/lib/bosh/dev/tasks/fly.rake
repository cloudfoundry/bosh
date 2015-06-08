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
    perform(db: 'postgresql') do
      sh("fly execute -p -c ci/concourse/tasks/test-integration.yml -i bosh-src=$PWD")
    end
  end

  task :run, [:command] do |_, args|
    perform do
      sh("COMMAND=\"#{args[:command]}\" fly execute -p -c ci/concourse/tasks/run.yml -i bosh-src=$PWD")
    end
  end

  def git_branch
    @git_branch ||= (ENV['GIT_BRANCH'] || `cat .git/HEAD`.split('/').last).strip
  end

  def perform(options = {})
    File.open('.fly_run', 'w') do |f|
      f.puts("export DB=#{options[:db]}") if options.has_key?(:db)
      f.puts("export GIT_BRANCH=#{git_branch}")
      f.puts('export RUBY_VERSION=2.1.6')
    end
    yield
  ensure
    File.delete('.fly_run') if File.exist?('.fly_run')
  end
end

desc 'Fly unit and integration specs'
task :fly => %w(fly:unit fly:integration)
