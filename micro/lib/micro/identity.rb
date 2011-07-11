require 'rest-client'
require 'yajl'

module VCAP
  module Micro
    class Identity
      attr_accessor :admins, :ip, :subdomain, :proxy

      MICRO_CONFIG = "/var/vcap/micro/micro.json"

      def initialize
        @client = RestClient::Resource.new(
          'http://micro.cloudfoundry.com/api/v1',
          :headers => { :content_type => 'application/json' }
        )
        if configured?
          load_config
        else
          # use some sane defaults in case we can't connect to the REST API
          # so it can be used offline
          @config ||= {
            "admins" => ["admin@vcap.me"],
            "subdomain" => "vcap.me"
          }
          @subdomain = @config['subdomain']
          @admins = @config['admins']
        end
        @config ||= {}
      end

      def configured?
        File.exist?(MICRO_CONFIG)
      end

      def load_config
        File.open(MICRO_CONFIG) do |f|
          @config = Yajl::Parser.parse(f)
          @subdomain = @config['subdomain']
          @admins = @config['admins']
          @ip = @config['ip']
          @auth_token = @config['auth_token']
        end
      end

      def install(ip)
        if @proxy.match(/\Ahttp/)
          RestClient.proxy = proxy
        end

        @ip = @config['ip'] = ip

        unless @auth_token
          resp = auth
          @admins = @config['admins'] = [ resp['email'] ]
          @subdomain = @config['subdomain'] = resp['hostname']
          @auth_token = @config['auth_token'] = resp['token']
        end

        update_dns
      end

      def auth
        path = "/auth/#{CGI.escape(@nounce)}"
        response = @client[path].get
        resp = Yajl::Parser.new.parse(response)
        resp
      end

      def update_dns
        dns_data = {:token => @auth_token, :ip => @ip}
        payload = Yajl::Encoder.encode(dns_data)
        begin
          @client['/update_dns'].put(payload)
        rescue RestClient::NotModified
          # Do nothing
        end
      end

      def update_ip(ip)
        @ip = @config['ip'] = ip
        save
        update_dns
      end

      def token(nounce)
        @nounce = nounce
      end

      def dns_wildcard_name(subsdomain)
        @subdomain = subdomain
      end

      def save
        File.open(MICRO_CONFIG, 'w') do |f|
          Yajl::Encoder.encode(@config, f)
        end
      end

    end
  end
end
