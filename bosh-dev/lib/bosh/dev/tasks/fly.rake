require 'rspec'
require 'bosh/dev/ruby_version'

namespace :fly do
  # bundle exec rake fly:unit
  desc 'Fly unit specs'
  task :unit do
    execute('test-unit')
  end

  # bundle exec rake fly:integration
  desc 'Fly integration specs'
  task :integration do
    env(DB: (ENV['DB'] || 'postgresql'))
    execute('test-integration', '-p')
  end

  # bundle exec rake fly:run["pwd ; ls -al"]
  task :run, [:command] do |_, args|
    env(COMMAND: %Q|\"#{args[:command]}\"|)
    execute('run', '-p')
  end

  private

  def concourse_target
    "-t #{ENV['CONCOURSE_TARGET']}" if ENV.has_key?('CONCOURSE_TARGET')
  end

  def env(modifications = {})
    @env ||= {
      RUBY_VERSION: ENV['RUBY_VERSION'] || Bosh::Dev::RubyVersion.release_version
    }
    @env.merge!(modifications) if modifications

    @env.to_a.map { |pair| pair.join('=') }.join(' ')
  end

  def execute(task, command_options =  nil)
    sh("#{env} fly #{concourse_target} execute #{command_options} -x -c ci/tasks/#{task}.yml -i bosh-src=$PWD")
  end
end

desc 'Fly unit and integration specs'
task :fly => %w(fly:unit fly:integration)
