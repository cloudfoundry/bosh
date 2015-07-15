require 'common/ssl'

module Bosh
  module AwsCliPlugin
    class MicroboshManifest
      attr_reader :vpc_receipt, :route53_receipt, :hm_director_password, :hm_director_user

      def initialize(vpc_receipt, route53_receipt, options={})
        @vpc_receipt = vpc_receipt
        @route53_receipt = route53_receipt
        @hm_director_user = options[:hm_director_user]
        @hm_director_password = options[:hm_director_password]
      end

      def file_name
        "micro_bosh.yml"
      end

      def deployment_name
        "micro"
      end

      def vpc_config
        vpc_receipt['original_configuration']
      end

      def name
        vpc_config['name'] || warning('Missing name field')
      end

      def vip
        route53_receipt['elastic_ips']['micro']['ips'][0] || warning('Missing vip field')
      end

      def subnet
        vpc_receipt['vpc']['subnets']['bosh1'] || warning('Missing bosh subnet field')
      end

      def network_type
        subnet ? 'manual' : 'dynamic'
      end

      def availability_zone
        vpc_config['vpc']['subnets']['bosh1']['availability_zone'] || warning('Missing availability zone in vpc.subnets.bosh')
      end

      def access_key_id
        vpc_config['aws']['access_key_id'] || warning('Missing aws access_key_id field')
      end

      def secret_access_key
        vpc_config['aws']['secret_access_key'] || warning('Missing aws secret_access_key field')
      end

      def region
        vpc_config['aws']['region'] || warning('Missing aws region field')
      end

      def key_pair_name
        vpc_config['key_pairs'].any? ? vpc_config['key_pairs'].keys[0] : warning("Missing key_pairs field, must have at least 1 keypair")
      end

      def private_key_path
        vpc_config['key_pairs'].any? ? vpc_config['key_pairs'].values[0].gsub(/\.pub$/, '') : warning("Missing key_pairs field, must have at least 1 keypair")
      end

      def compiled_package_cache?
        !!vpc_config['compiled_package_cache']
      end

      def cache_access_key_id
        vpc_config['compiled_package_cache']['access_key_id'] || warning('Missing compiled_package_cache access_key_id field')
      end

      def cache_secret_access_key
        vpc_config['compiled_package_cache']['secret_access_key'] || warning('Missing compiled_package_cache secret_access_key field')
      end

      def cache_bucket_name
        vpc_config['compiled_package_cache']['bucket_name'] || warning('Missing compiled_package_cache bucket_name field')
      end

      def director_ssl_key
        certificate.key.gsub("\n", "\n          ")
      end

      def director_ssl_cert
        certificate.certificate.gsub("\n", "\n          ")
      end

      def certificate
        @cert if @cert
        key_path = director_ssl['private_key_path'] || 'director.key'
        cert_path = director_ssl['certificate_path'] || 'director.pem'
        @cert = Bosh::Ssl::Certificate.new(key_path, cert_path, "*.#{vpc_config['vpc']['domain']}").load_or_create
      end

      def director_ssl
        ssl_certs['director_cert'] || {}
      end

      def ssl_certs
        vpc_config['ssl_certs'] || {}
      end

      # RSpec overloads to_yaml when you set up expectations on an object;
      # so to_y is just a way to get directly at the to_yaml implementation without fighting RSpec.
      def to_y
        ERB.new(File.read(get_template("micro_bosh.yml.erb"))).result(binding)
      end

      def to_yaml
        to_y
      end

      def get_template(template)
        File.expand_path("../../../templates/#{template}", __FILE__)
      end
    end
  end
end
