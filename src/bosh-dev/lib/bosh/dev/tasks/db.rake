namespace :db do
  desc 'Dump database'
  task :dump do
    director_config = {
      'db' => {
        'database' => "director_latest_tmp",
        'adapter' => 'postgresql',
        'user' => 'postgres'
      },
      'cloud' => {}
    }
    director_config_path = Tempfile.new('director_config')
    File.open(director_config_path.path, 'w') { |f| f.write(YAML.dump(director_config)) }

    require 'bosh/dev/sandbox/postgresql'
    @logger = Logging.logger(STDOUT)
    @database = Bosh::Dev::Sandbox::Postgresql.new(director_config['db']['database'], @logger, 5432)
    @database.drop_db
    @database.create_db

    require 'bosh/dev/sandbox/database_migrator'
    director_dir = File.expand_path('../../../../../../bosh-director', __FILE__)
    Bosh::Dev::Sandbox::DatabaseMigrator.new(director_dir, director_config_path.path, @logger).migrate
    File.unlink(director_config_path)

    File.open('postgresql.dump.sql', 'w') do |f|
      f.puts @database.dump_db
    end
  end

  desc 'Describe database tables'
  task :describe do
    director_config = {
      'db' => {
        'database' => "director_latest_tmp",
        'adapter' => 'postgresql',
        'user' => 'postgres'
      },
      'cloud' => {}
    }
    director_config_path = Tempfile.new('director_config')
    File.open(director_config_path.path, 'w') { |f| f.write(YAML.dump(director_config)) }

    require 'bosh/dev/sandbox/postgresql'
    @logger = Logging.logger(STDOUT)
    @database = Bosh::Dev::Sandbox::Postgresql.new(director_config['db']['database'], @logger, 5432)
    @database.drop_db
    @database.create_db

    require 'bosh/dev/sandbox/database_migrator'
    director_dir = File.expand_path('../../../../../../bosh-director', __FILE__)
    Bosh::Dev::Sandbox::DatabaseMigrator.new(director_dir, director_config_path.path, @logger).migrate
    File.unlink(director_config_path)

    File.open('postgresql.tables.txt', 'w') do |f|
      f.puts @database.describe_db
    end
  end
end
