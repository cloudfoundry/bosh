require 'rest-client'
require 'yajl'

module VCAP
  module Micro
    class Identity 
      MICRO_CONFIG = "/var/vcap/micro/micro.json"

      def initialize
        @client = RestClient::Resource.new(
          'http://cf.vcloudlabs.com/api/v1',
          :headers => { :content_type => 'application/json' }
        )
      end

      def configured?
        File.exist?(MICRO_CONFIG)
      end

      def install(ip)
        @ip = ip

        config = auth
        @admin = config['email']
        @domain = config['hostname']
        @auth_token = config['token']
        config['ip'] = @ip

        update_dns

        File.open(MICRO_CONFIG, 'w') do |f|

          f.write(Yajl::Encoder.encode(config))
        end
      end

      def update_dns
        dns_data = {:token => @auth_token, :ip => @ip}
        payload = Yajl::Encoder.encode(dns_data)
        begin
          p @client['/update_dns']
          p payload

          @client['/update_dns'].put(payload)
          puts "first"
        rescue RestClient::NotModified
          puts "second"
          # Do nothing
        end
      end

      def token(nounce)
        @nounce = nounce
      end

      def auth
        path = "/auth/#{CGI.escape(@nounce)}"
        response = @client[path].get
        conf = Yajl::Parser.new.parse(response)
        conf
      end

      def dns_wildcard_name(name)
      end

      def self.setup_admin(admin_email)
      end

      def self.admin?
        # An admin is defined - e.g. through token
      end

    end
  end
end
