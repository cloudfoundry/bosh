require 'bosh/dev/db/db_helper'

require 'integration_support/database_migrator'

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
      Bosh::Dev::DB::DBHelper.build(db_options: db_options)
    db_helper.drop_db
    db_helper.create_db

    config = Tempfile.new("#{director_config['db']['database']}-config.yml")
    File.write(config, YAML.dump(director_config))
    IntegrationSupport::DatabaseMigrator.new(
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

  namespace :migration do
    desc 'Generate new migration with NAME'
    task :generate, :name do |_, args|
      name = args.to_hash.fetch(:name)

      timestamp = Time.new.getutc.strftime('%Y%m%d%H%M%S')
      new_migration_path = "bosh-director/db/migrations/director/#{timestamp}_#{name}.rb"
      new_migration_spec_path = "bosh-director/spec/unit/db/migrations/director/#{timestamp}_#{name}_spec.rb"

      puts "Creating #{new_migration_spec_path}"
      File.write new_migration_spec_path, <<EOF
require 'db_spec_helper'

module Bosh::Director
  RSpec.describe '#{File.basename(new_migration_path)}' do
    let(:db) { DBSpecHelper.db }

    before { DBSpecHelper.migrate_all_before(subject) }

    it 'TODO: describe what it does' do
      # PRE_MIGRATION expectation(s0

      DBSpecHelper.migrate(subject)

      # POST_MIGRATION expectation(s0
    end
  end
end
EOF

      puts "Creating #{new_migration_path}"
      File.write new_migration_path, <<EOF
Sequel.migration do
  change do
    # TODO https://github.com/jeremyevans/sequel/blob/master/doc/migration.rdoc
  end
end
EOF
    end

    desc 'Generate digest for a migration file'
    task :generate_digest, :name do |_, args|
      require 'json'
      name = args.to_hash.fetch(:name)
      migrations_dir = 'bosh-director/db/migrations'

      migration_digests = File.join(migrations_dir, "migration_digests.json")

      digest_migration_json = JSON.parse(File.read(migration_digests))
      if digest_migration_json[name] != nil
        puts '
        YOU ARE MODIFYING A DB MIGRATION DIGEST.
        IF THIS MIGRATION HAS ALREADY BEEN RELEASED, IT MIGHT RESULT IN UNDESIRABLE BEHAVIOR.
        YOU HAVE BEEN WARNED.
        '
      end
      digest_migration_json[name] =
        Digest::SHA1.hexdigest(File.read(File.join(migrations_dir, 'director', "#{name}.rb")))

      File.write(migration_digests, JSON.pretty_generate(digest_migration_json))
    end
  end
end
