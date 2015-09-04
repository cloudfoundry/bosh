namespace :migrations do
  namespace :bosh_director do
    desc 'Generate new migration with NAME (there are two namespaces: dns, director)'
    task :new, :name, :namespace do |_, args|
      args = args.to_hash
      name = args.fetch(:name)
      namespace = args.fetch(:namespace)

      timestamp = Time.new.getutc.strftime('%Y%m%d%H%M%S')
      new_migration_path = "bosh-director/db/migrations/#{namespace}/#{timestamp}_#{name}.rb"

      puts "Creating #{new_migration_path}"
      FileUtils.touch(new_migration_path)
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

  namespace :bosh_cli_plugin_aws do
    desc 'Generate a new AWS migration with NAME'
    task :new, :name do |_, args|
      args = args.to_hash
      name = args.fetch(:name)

      require 'bosh_cli_plugin_aws/migration_helper'

      Bosh::AwsCliPlugin::MigrationHelper.generate_migration_file(name)
    end
  end
end
