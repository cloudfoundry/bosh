require 'yaml'

module Bosh
  module AwsCliPlugin
    class ConfigurationInvalid < RuntimeError; end

    class AwsConfig
      def initialize(filename, env = ENV)
        @filename = filename
        @env = env
      end

      def configuration
        load_configuration(File.read(@filename))
      end

      def fetch_from_env(key, msg=nil)
        @env.fetch(key) {
          msg ||= "Missing ENV variable #{key}"
          raise(ConfigurationInvalid, msg)
        }
      end

      def aws_secret_access_key
        fetch_from_env("BOSH_AWS_SECRET_ACCESS_KEY")
      end

      def aws_access_key_id
        fetch_from_env("BOSH_AWS_ACCESS_KEY_ID")
      end

      def aws_region
        @env.fetch('BOSH_AWS_REGION', 'us-east-1')
      end

      def vpc_domain
        @env["BOSH_VPC_DOMAIN"]
      end

      def vpc_subdomain
        @env["BOSH_VPC_SUBDOMAIN"]
      end

      def vpc_deployment_name
        if has_vpc_subdomain?
          vpc_subdomain
        elsif has_vpc_domain?
          vpc_domain.gsub('.', '-')
        else
          "deployment"
        end
      end

      def vpc_generated_domain
        if has_vpc_domain? && has_vpc_subdomain?
          "#{vpc_subdomain}.#{vpc_domain}"
        elsif has_vpc_subdomain?
          "#{vpc_subdomain}.cf-app.com"
        elsif has_vpc_domain?
          vpc_domain
        else
          raise(ConfigurationInvalid, "No domain and subdomain are defined.")
        end
      end

      def has_vpc_domain?
        vpc_domain && vpc_domain != ""
      end

      def has_vpc_subdomain?
        vpc_subdomain && vpc_subdomain != ""
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

      def elb_ssl_key_file
        @env.fetch("BOSH_AWS_ELB_SSL_KEY", "elb-cfrouter.key")
      end

      def elb_ssl_cert_file
        @env.fetch("BOSH_AWS_ELB_SSL_CERT", "elb-cfrouter.pem")
      end

      def elb_ssl_cert_chain_file
        @env["BOSH_AWS_ELB_SSL_CHAIN"]
      end

      def director_ssl_key_file
        @env.fetch("BOSH_DIRECTOR_SSL_KEY", "director.key")
      end

      def director_ssl_cert_file
        @env.fetch("BOSH_DIRECTOR_SSL_CERT", "director.pem")
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

      def production_resources?
        @env['BOSH_PRODUCTION_RESOURCES']
      end

      def load_configuration(yaml)
        renderer = ERB.new(yaml, 0, '<>%-')

        YAML.load(renderer.result(binding))
      end
    end
  end
end
