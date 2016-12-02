namespace :migrations do
  namespace :bosh_director do
    desc 'Generate new migration with NAME (there are two namespaces: dns, director)'
    task :new, :name, :namespace do |_, args|
      args = args.to_hash
      name = args.fetch(:name)
      namespace = args.fetch(:namespace)

      timestamp = Time.new.getutc.strftime('%Y%m%d%H%M%S')
      new_migration_path = "bosh-director/db/migrations/#{namespace}/#{timestamp}_#{name}.rb"
      new_migration_spec_path = "bosh-director/spec/unit/db/migrations/#{namespace}/#{timestamp}_#{name}_spec.rb"

      puts "Creating #{new_migration_path}"
      puts "Creating #{new_migration_spec_path}"
      FileUtils.touch(new_migration_path)
      FileUtils.touch(new_migration_spec_path)
    end
  end

  namespace :bosh_registry do
    desc 'Generate new migration with NAME'
    task :new, :name do |_, args|
      args = args.to_hash
      name = args.fetch(:name)

      timestamp = Time.new.getutc.strftime('%Y%m%d%H%M%S')
      new_migration_path = "bosh-registry/db/migrations/#{timestamp}_#{name}.rb"

      puts "Creating #{new_migration_path}"
      FileUtils.touch(new_migration_path)
    end
  end

  namespace :schema do
    desc 'Dump database schema files'
    task :dump do
      path = Tempfile.new('generated_schema')
      director_config = {
        'db' => {
          'database' => "#{path.path}.sqlite",
          'adapter' => 'sqlite',
          'host' => '127.0.0.1'
        }
      }

      director_config_path = Tempfile.new('director_config')
      File.open(director_config_path.path, 'w') { |f| f.write(YAML.dump(director_config)) }

      require 'bosh/dev/sandbox/database_migrator'
      director_dir = File.expand_path('../../../../../../bosh-director', __FILE__)
      Bosh::Dev::Sandbox::DatabaseMigrator.new(director_dir, director_config_path.path, Logger.new('debug')).migrate
      File.unlink(path)
      File.unlink(director_config_path)

      require 'bosh/director'
      Bosh::Director::Config.db = Bosh::Director::Config.configure_db(director_config['db'])
      Bosh::Director::Config.db.extension :bosh_schema_caching

      require 'bosh/director/models'
      require 'delayed_job_sequel'
      Delayed::Worker.backend = :sequel

      Bosh::Director::Config.db.dump_schema_cache(File.expand_path('../../../../../../bosh-director/db/schema.dump', __FILE__))
    end
  end
end
