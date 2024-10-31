require 'yaml'

module IntegrationSupport
  class PostgresVersionHelper
    class << self
      def ensure_version_match!(env_db)
        return unless env_db == 'postgresql'

        unless local_major_version == release_major_version
          raise "Postgres major version mismatch: jobs/postgres?spec.yml: #{local_version}; local: #{release_version}."
        end
      end

      def local_major_version
        local_version.split('.')[0]
      end

      def local_version
        `postgres --version`.chomp.split(' ').last
      end

      def release_major_version
        release_version.split('.')[0]
      end

      def release_version
        @release_version ||= begin
          postgres_release_config =
            YAML.load_file(
              File.join(Bosh::Dev::RELEASE_ROOT, 'jobs', 'postgres', 'spec.yml'),
              permitted_classes: [Symbol],
              aliases: true,
            )

          # sort alphanumerics correctly, e.g. 10 > 9
          postgres_version = postgres_release_config['packages'].max_by { |s| s.scan(/\d+/).first.to_i }

          postgres_version.split('-').last
        end
      end
    end
  end
end

RSpec.configure do |c|
  c.before(:suite) do
    IntegrationSupport::PostgresVersionHelper.ensure_version_match!(ENV['DB'])
  end
end
