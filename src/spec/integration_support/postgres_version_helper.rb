require 'integration_support/constants'

module IntegrationSupport
  class PostgresVersionHelper
    class << self
      def ensure_version_match!(env_db)
        return unless env_db == 'postgresql'

        unless local_major_version == configured_major_version
          raise "Postgres major version mismatch: PG_VERSION=#{configured_version}; local: #{local_version}."
        end
      end

      def local_major_version
        local_version.split('.')[0]
      end

      def local_version
        `postgres --version`.chomp.split(' ').last
      end

      def configured_major_version
        configured_version.split('.')[0]
      end

      def configured_version
        ENV.fetch('PG_VERSION') do
          raise 'PG_VERSION environment variable must be set when DB=postgresql'
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
