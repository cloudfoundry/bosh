require 'yaml'
require 'integration_support/constants'

module IntegrationSupport
  class PostgresVersionHelper
    class << self
      def ensure_version_match!(env_db)
        return unless env_db == 'postgresql'

        unless local_major_version == expected_major_version
          raise "Postgres major version mismatch: expected (#{expected_version_source}): #{expected_version}; local: #{local_version}."
        end
      end

      def local_major_version
        local_version.split('.')[0]
      end

      def local_version
        `postgres --version`.chomp.split(' ')[2].split('.')[0]
      end

      def expected_major_version
        expected_version.split('.')[0]
      end

      def expected_version
        pg_version_override || release_version
      end

      def expected_version_source
        pg_version_override ? 'PG_VERSION' : 'jobs/postgres/spec'
      end

      def pg_version_override
        value = ENV.fetch('PG_VERSION', '').strip
        value.empty? ? nil : value
      end

      def release_version
        @release_version ||= begin
          postgres_release_config =
            YAML.load_file(
              File.join(IntegrationSupport::Constants::BOSH_REPO_ROOT, 'jobs', 'postgres', 'spec'),
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
