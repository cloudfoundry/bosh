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
