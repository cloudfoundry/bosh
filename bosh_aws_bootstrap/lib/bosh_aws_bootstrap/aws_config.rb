require 'yaml'

module Bosh
  module Aws
    class ConfigurationInvalid < RuntimeError; end

    class AwsConfig
      def initialize(filename, env = ENV)
        @filename = filename
        @env = env
      end

      def configuration
        load_configuration(File.read(@filename))
      end

      def fetch_from_env(key)
        @env.fetch(key) {
          raise(ConfigurationInvalid, "Missing ENV variable #{key}")
        }
      end

      def aws_secret_access_key
        fetch_from_env("BOSH_AWS_SECRET_ACCESS_KEY")
      end

      def aws_access_key_id
        fetch_from_env("BOSH_AWS_ACCESS_KEY_ID")
      end

      def vpc_domain
        domain = @env.fetch("BOSH_VPC_DOMAIN", "cf-app.com")
        subdomain = vpc_subdomain

        "#{subdomain}.#{domain}"
      end

      def vpc_subdomain
        fetch_from_env("BOSH_VPC_SUBDOMAIN")
      end

      def vpc_primary_az
        fetch_from_env("BOSH_VPC_PRIMARY_AZ")
      end

      def vpc_secondary_az
        fetch_from_env("BOSH_VPC_SECONDARY_AZ")
      end

      def key_pair_name
        @env.fetch("BOSH_KEY_PAIR_NAME", "bosh")
      end

      def key_pair_path
        @env.fetch("BOSH_KEY_PATH", "#{@env['HOME']}/.ssh/id_rsa_bosh")
      end

      def ssl_key_file
        @env.fetch("BOSH_SSL_KEY", "elb-cfrouter.key")
      end

      def ssl_cert_file
        @env.fetch("BOSH_SSL_CERT", "elb-cfrouter.pem")
      end

      def ssl_cert_chain_file
        @env["BOSH_SSL_CHAIN"]
      end

      def has_package_cache_configuration?
        cache_access_key_id
      end

      def cache_access_key_id
        @env["BOSH_CACHE_ACCESS_KEY_ID"]
      end

      def cache_secret_access_key
        unless has_package_cache_configuration?
          raise ConfigurationInvalid, "Missing ENV variable BOSH_CACHE_ACCESS_KEY_ID"
        end

        fetch_from_env("BOSH_CACHE_SECRET_ACCESS_KEY")
      end

      def cache_bucket_name
        @env.fetch("BOSH_CACHE_BUCKET_NAME", "bosh-global-package-cache")
      end

      def load_configuration(yaml)
        renderer = ERB.new(yaml)

        YAML.load(renderer.result(binding))
      end
    end
  end
end
