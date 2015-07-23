module Bosh
  module AwsCliPlugin
    class Migrator

      def initialize(config)
        @config = config
        @migration_path = MigrationHelper.aws_migration_directory
      end

      def migrate
        return unless needs_migration?

        run_migrations(pending_migrations)
      end

      def migrate_version(version)
        return unless needs_migration?

        migration_to_run = pending_migrations.detect do |migration|
          migration.version == version.to_i
        end

        run_migrations([migration_to_run])
      end

      def pending_migrations
        migrations - environment_migrations
      end

      def migrations
        @migrations ||= load_migrations
      end

      def environment_migrations
        @environment_migrations ||= load_migrations_for_env
      end

      def needs_migration?
        ensure_bucket_exists
        environment_migrations.nil? || environment_migrations != migrations
      end

      private

      attr_reader :migration_path

      def aws_s3
        @aws_s3 ||= Bosh::AwsCliPlugin::S3.new(@config['aws'])
      end

      def ensure_bucket_exists
        unless aws_s3.bucket_exists?(bucket_name)
          aws_s3.create_bucket(bucket_name)
        end
      end

      def s3_safe_vpc_domain
        @config['vpc']['domain'].gsub('.', '-')
      end

      def bucket_name
        if aws_s3.bucket_exists?("#{@config['name']}-bosh-artifacts")
          "#{@config['name']}-bosh-artifacts"
        else
          "#{s3_safe_vpc_domain}-bosh-artifacts"
        end
      end

      def migrations_name
        "aws_migrations/migrations.yaml"
      end

      def run_migrations(migrations_to_run)
        migrations_to_run.each do |migration|
          migration.load_class.new(@config, bucket_name).run
          record_migration(migration)
        end
      end

      def load_migrations
        Dir.glob(File.join(migration_path, "*.rb")).collect do |migration_file_path|
          version, name  = migration_file_path.scan(/([0-9]+)_([_a-z0-9]*).rb\z/).first
          MigrationProxy.new(name,version.to_i)
        end.sort
      end

      def load_migrations_for_env
        yaml_file = aws_s3.fetch_object_contents(bucket_name, migrations_name) || ""
        migrations = YAML.load(yaml_file) || []

        migrations.collect do |migration_yaml|
          MigrationProxy.new(migration_yaml['name'],migration_yaml['version'].to_i)
        end.sort
      end

      def record_migration(migration)
        environment_migrations << migration
        migration_yaml = YAML.dump(environment_migrations.collect do |m|
          m.to_hash
        end)
        aws_s3.upload_to_bucket(bucket_name, migrations_name, migration_yaml)
      end
    end

    class MigrationProxy
      include Comparable

      attr_reader :name, :version

      def initialize(name, version)
        @name = name
        @version = version.to_i
      end

      def load_class
        require File.join(MigrationHelper.aws_migration_directory, "#{version}_#{name}")
        Object.const_get(MigrationHelper.to_class_name(name))
      end

      def eql?(other)
        version == other.version
      end

      def <=>(other)
        version <=> other.version
      end

      def hash
        (name.to_s + version.to_s).hash
      end

      def to_hash
        {"name" => name, "version" => version}
      end
    end
  end
end
