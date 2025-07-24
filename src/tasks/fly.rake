namespace :fly do
  desc 'Fly unit specs'
  task :unit do
    db, db_version = fetch_db_and_version('sqlite')

    execute('test-rake-task', command_opts('unit', db, db_version),
            RAKE_TASK: ENV.fetch('RAKE_TASK', 'spec:unit:parallel'),
            DB: db,
            COVERAGE: ENV.fetch('COVERAGE', false))
  end

  desc 'Fly integration specs'
  task :integration, [:cli_dir] do |_, args|
    db, db_version = fetch_db_and_version('postgresql')

    command_opts = command_opts('integration', db, db_version)
    command_opts += " --input bosh-cli=#{args[:cli_dir]}" if args[:cli_dir]

    execute('test-rake-task', command_opts,
            DB: db,
            COVERAGE: ENV.fetch('COVERAGE', false),
            RAKE_TASK: 'spec:integration',
            SPEC_PATH: ENV.fetch('SPEC_PATH', nil))
  end

  private

  def fetch_db_and_version(default_db)
    db = ENV.fetch('DB', default_db)

    case db
    when 'postgresql'
      db_version = ENV.fetch('DB_VERSION', '15')
    when 'mysql'
      db_version = ENV.fetch('DB_VERSION', '8.0')
    when 'sqlite'
      db_version = nil
    else
      fail "invalid DB: '#{db}'"
    end

    [db, db_version]
  end

  def command_opts(test_type, db, db_version)
    [
      '--privileged',
      input_from(test_type, db, db_version),
      image(db, db_version)
    ].join(' ')
  end

  def db_short_name(db)
    db == 'postgresql' ? 'postgres' : db
  end

  def db_short_version(db_version)
    db_version.split('.').first
  end

  def input_from(test_type, db, db_version)
    case test_type
    when 'unit'
      if db == 'sqlite'
        "--inputs-from bosh-director/#{test_type}-director-#{db_short_name(db)}"
      else
        "--inputs-from bosh-director/#{test_type}-director-#{db_short_name(db)}-#{db_short_version(db_version)}"
      end

    when 'integration'
      "--inputs-from bosh-director/#{test_type}-#{db_short_name(db)}"

    else
      fail "invalid test_type: '#{test_type}'"
    end
  end

  def image(db, db_version)
    if db == 'sqlite'
      '--image integration-image'
    else
      "--image integration-#{db_short_name(db)}-#{db_version.gsub('.', '-')}-image"
    end
  end

  def concourse_tag
    tag = ENV.fetch('CONCOURSE_TAG', '')
    "--tag=#{tag}" unless tag.empty?
  end

  def concourse_target
    "--target #{ENV.fetch('CONCOURSE_TARGET', 'bosh')}"
  end

  def prepare_env(additional_env = {})
    env = {
    }
    env.merge!(additional_env)

    env.to_a.map { |pair| pair.join('=') }.join(' ')
  end

  def execute(task, command_options = nil, additional_env = {})
    env = prepare_env(additional_env)

    execute_cmd = [
      'execute',
      concourse_tag,
      command_options,
      "--config ../ci/tasks/#{task}.yml",
      '--input bosh=$PWD/../',
      '--input bosh-ci=$PWD/../',
    ]
    sh("#{env} fly #{concourse_target} #{execute_cmd.join(' ')}")
  end
end
