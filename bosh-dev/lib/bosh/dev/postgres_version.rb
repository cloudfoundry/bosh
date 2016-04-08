require 'yaml'
require 'pg'
require 'bosh/director/config'

module Bosh::Dev
  class PostgresVersion
    class << self

      def local_version
        `postgres --version`.chomp.split(' ').last
      end

      def release_version
        @release_version ||= begin
          postgres_release_config = YAML::load_file(File.join(File.dirname(__FILE__), '../../../../release/jobs/postgres-9.4/spec.yml'))
          postgres_version = postgres_release_config['packages'].sort.last

          postgres_version.split('-').last
        end
      end
    end
  end
end
