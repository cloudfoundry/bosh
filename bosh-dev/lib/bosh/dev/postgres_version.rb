require 'yaml'
require 'pg'
require 'bosh/director/config'

module Bosh::Dev
  # class RubyVersion
  #   class << self
  #     def legacy_version
  #       '1.9.3'
  #     end
  #
  #     def release_version
  #       @release_version ||= begin
  #         spec_path = '../../../../release/packages/ruby/spec'
  #         ruby_spec = YAML.load_file(File.join(File.dirname(__FILE__), spec_path))
  #         ruby_spec['files'].find { |f| f =~ /ruby-(.*).tar.gz/ }
  #         $1
  #       end
  #     end
  #
  #     def supported
  #       @supported ||= [legacy_version, release_version]
  #     end
  #   end
  # end

  class PostgresVersion
    class << self

      def local_version
        `postgres --version`.chomp.split(' ').last
      end

      def release_version
        @release_version ||= begin
          postgres_release_config = YAML::load(File.open('../release/jobs/postgres/spec.yml'))
          postgres_version = postgres_release_config['packages'].sort.last

          postgres_version.split('-').last
        end
      end
    end
  end
end
