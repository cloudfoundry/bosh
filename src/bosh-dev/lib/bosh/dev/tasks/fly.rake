require 'rspec'

namespace :fly do
  # bundle exec rake fly:unit
  desc 'Fly unit specs'
  task :unit do
    execute('test-unit', '-p',
      DB: ENV.fetch('DB', 'postgresql'),
      DB_VERSION: ENV.fetch('DB_VERSION', '15'),
      DB_TLS: ENV.fetch('DB_TLS', true))
  end

  # bundle exec rake fly:integration
  desc 'Fly integration specs'
  task :integration, [:cli_dir] do |_, args|
    command_opts = '-p --inputs-from bosh-director/integration-db-tls-postgres'
    command_opts += " -i bosh-cli=#{args[:cli_dir]}" if args[:cli_dir]

    execute('test-integration', command_opts,
            DB: ENV.fetch('DB', 'postgresql'),
            DB_VERSION: ENV.fetch('DB_VERSION', '15'),
            DB_TLS: ENV.fetch('DB_TLS', true),
            SPEC_PATH: ENV.fetch('SPEC_PATH', nil))
  end

  # bundle exec rake fly:run["pwd ; ls -al"]
  task :run, [:command] do |_, args|
    execute('run', '-p',
            COMMAND: %(\"#{args[:command]}\"))
  end

  private

  def concourse_tag
    tag = ENV.fetch('CONCOURSE_TAG', '')
    "--tag=#{tag}" unless tag.empty?
  end

  def concourse_target
    "-t #{ENV.fetch('CONCOURSE_TARGET', 'director')}"
  end

  def prepare_env(additional_env = {})
    env = {
      RUBY_VERSION: ENV['RUBY_VERSION'] || RUBY_VERSION,
    }
    env.merge!(additional_env)

    env.to_a.map { |pair| pair.join('=') }.join(' ')
  end

  def execute(task, command_options = nil, additional_env = {})
    env = prepare_env(additional_env)
    sh("#{env} fly #{concourse_target} sync")
    sh(
      "#{env} fly #{concourse_target} execute #{concourse_tag} #{command_options} -c ../ci/tasks/#{task}.yml -i bosh-src=$PWD/../",
    )
  end
end

desc 'Fly unit and integration specs'
task fly: %w[fly:unit fly:integration]
