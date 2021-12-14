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

      puts "Creating #{new_migration_spec_path}"
      File.write new_migration_spec_path, <<EOF
require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '#{File.basename(new_migration_path)}' do
    let(:db) {DBSpecHelper.db}

    before do
      DBSpecHelper.migrate_all_before(subject)
      DBSpecHelper.migrate(subject)
    end

    # TODO
  end
end
EOF

      puts "Creating #{new_migration_path}"
      File.write new_migration_path, <<EOF
Sequel.migration do
  up do
    # TODO https://github.com/jeremyevans/sequel/blob/master/doc/migration.rdoc
  end
end
EOF
    end

    desc 'Generate digest for a migration file'
    task :generate_migration_digest, :name, :namespace do |_, args|
      args = args.to_hash
      name = args.fetch(:name)
      namespace = args.fetch(:namespace)

      generate_migration_digest("bosh-director/db/migrations", namespace, name)
    end
  end

  def generate_migration_digest(migrations_dir, namespace, name)
    require 'json'
    new_migration_path = File.join(migrations_dir, "#{namespace}","#{name}.rb")
    migration_digests = File.join(migrations_dir, "migration_digests.json")

    migration_digest = Digest::SHA1.hexdigest(File.read(new_migration_path))

    digest_migration_json = JSON.parse(File.read(migration_digests))
    if digest_migration_json[name] != nil then
      puts '
        YOU ARE MODIFIFYING A DB MIGRATION DIGEST.
        IF THIS MIGRATION HAS ALREADY BEEN RELEASED, IT MIGHT RESULT IN UNDESIRABLE BEHAVIOR.
        YOU HAVE BEEN WARNED.
        '
    end
    digest_migration_json[name] = migration_digest
    File.write(migration_digests, JSON.pretty_generate(digest_migration_json))
  end
end
