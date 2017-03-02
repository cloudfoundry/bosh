require 'rspec'
require 'bosh/dev/ruby_version'

namespace :fly do
  # bundle exec rake fly:unit
  desc 'Fly unit specs'
  task :unit do
    execute('test-unit', '-p', {
        DB: (ENV['DB'] || 'postgresql'),
        DB_VERSION: (ENV['DB_VERSION'] || '9.4')
    })
  end

  # bundle exec rake fly:integration
  desc 'Fly integration specs'
  task :integration do
    execute('test-integration', '-p --inputs-from bosh/integration-2.3-postgres', {
        DB: (ENV['DB'] || 'postgresql'), SPEC_PATH: (ENV['SPEC_PATH'] || nil)
    })
  end

  # bundle exec rake fly:integration_gocli
  desc 'Fly integration gocli specs'
  task :integration_gocli do
    execute('test-integration-gocli', '-p --inputs-from bosh/integration-postgres-gocli-sha2', {
        DB: (ENV['DB'] || 'postgresql'), SPEC_PATH: (ENV['SPEC_PATH'] || nil)
    })
  end

  # bundle exec rake fly:run["pwd ; ls -al"]
  task :run, [:command] do |_, args|
    execute('run', '-p', {
        COMMAND: %Q|\"#{args[:command]}\"|
    })
  end

  desc 'Fly integration parallel specs'
  task :integration_parallel do

    num_workers = 3
    num_groups = 24

    groups = (1..num_groups).group_by { |i| i%num_workers }.values
        .map { |group_values| group_values.join(',') }

    task_names = groups.each_with_index.map do |group, index|
      name = "integration_#{index + 1}"
      task name do
        execute('test-integration', '-p --inputs-from bosh/integration-2.3-postgres', {
            DB: (ENV['DB'] || 'postgresql'),
            SPEC_PATH: (ENV['SPEC_PATH'] || nil),
            GROUP: group,
            NUM_GROUPS: num_groups
        })
      end
      name
    end

    multitask _parallel_integration: task_names
    Rake::MultiTask[:_parallel_integration].invoke
  end

  desc 'Fly integration gocli parallel specs'
  task :integration_gocli_parallel do

    num_workers = 3
    num_groups = 24

    groups = (1..num_groups).group_by { |i| i%num_workers }.values
                 .map { |group_values| group_values.join(',') }

    task_names = groups.each_with_index.map do |group, index|
      name = "integration_#{index + 1}"
      task name do
        execute('test-integration-gocli', '-p --inputs-from=bosh/integration-postgres-gocli-sha2', {
            DB: (ENV['DB'] || 'postgresql'),
            SPEC_PATH: (ENV['SPEC_PATH'] || nil),
            GROUP: group,
            NUM_GROUPS: num_groups
        })
      end
      name
    end

    multitask _parallel_integration: task_names
    Rake::MultiTask[:_parallel_integration].invoke
  end

  private

  def concourse_tag
    tag = ENV.fetch('CONCOURSE_TAG', 'fly-integration')
    "--tag=#{tag}" unless tag.empty?
  end

  def concourse_target
    "-t #{ENV['CONCOURSE_TARGET']}" if ENV.has_key?('CONCOURSE_TARGET')
  end

  def prepare_env(additional_env = {})
    env = {
        RUBY_VERSION: ENV['RUBY_VERSION'] || Bosh::Dev::RubyVersion.release_version
    }
    env.merge!(additional_env)

    env.to_a.map { |pair| pair.join('=') }.join(' ')
  end

  def execute(task, command_options = nil, additional_env = {})
    env = prepare_env(additional_env)
    sh("#{env} fly #{concourse_target} sync")
    sh("#{env} fly #{concourse_target} execute #{concourse_tag} #{command_options} -x -c ../ci/tasks/#{task}.yml -i bosh-src=$PWD/../")
  end
end

desc 'Fly unit and integration specs'
task :fly => %w(fly:unit fly:integration)
