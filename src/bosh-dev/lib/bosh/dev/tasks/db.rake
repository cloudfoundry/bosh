require 'bosh/dev/db/db_helper'
require 'bosh/dev/sandbox/database_migrator'

class RakeDbHelper
  def self.db_adapter
    ENV.fetch('DB', Bosh::Dev::DB::DBHelper::POSTGRESQL)
  end

  def self.prepared_db_helper
    director_config = {
      'db' => {
        'adapter' => db_adapter,
        'database' => 'director_latest_tmp',
      },
      'cloud' => {}
    }

    db_options = {
      type: director_config['db']['adapter'],
      name: director_config['db']['database'],
      username: director_config['db']['user'],
    }

    db_helper =
      Bosh::Dev::DB::DBHelper.build(db_options: db_options, logger: Logging.logger(STDOUT))
    db_helper.drop_db
    db_helper.create_db

    config = Tempfile.new("#{director_config['db']['database']}-config.yml")
    File.write(config, YAML.dump(director_config))
    Bosh::Dev::Sandbox::DatabaseMigrator.new(
      File.join(Bosh::Dev::RELEASE_SRC_DIR, 'bosh-director'),
      config.path,
      Logging.logger(STDOUT)
    ).migrate
    config.unlink

    db_helper
  end
end

namespace :db do
  desc 'Dump database'
  task :dump do
    db_helper = RakeDbHelper.prepared_db_helper

    File.write("#{RakeDbHelper.db_adapter}.dump.sql", db_helper.dump_db)
  end

  desc 'Describe database tables'
  task :describe do
    db_helper = RakeDbHelper.prepared_db_helper

    File.write("#{RakeDbHelper.db_adapter}.tables.txt", db_helper.describe_db)
  end
end
