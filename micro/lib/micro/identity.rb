require 'rest-client'
require 'yajl'

module VCAP
  module Micro
    class Identity
      attr_accessor :admins, :ip, :proxy, :nonce
      attr_reader :name, :cloud

      URL = "http://www-com-sa.cloudfoundry.com/api/v1/micro"
      MICRO_CONFIG = "/var/vcap/micro/micro.json"
      CLOUD = "cloudfoundry.me"

      def initialize(config_file=MICRO_CONFIG)
        @config_file = config_file
        load_config if configured?
        @config ||= {}
        @client = resource
      end

      def configured?
        File.exist?(@config_file)
      end

      def load_config
        File.open(@config_file) do |f|
          @config = Yajl::Parser.parse(f)
          @name = @config['name']
          @cloud = @config['cloud']
          @admins = @config['admins']
          @ip = @config['ip']
          @token = @config['token']
        end
      end

      def resource
        headers = { :content_type => 'application/json' }
        headers["Auth-Token"] = @token if @token
        RestClient::Resource.new(URL, :headers => headers)
      end

      def install(ip)
        if @proxy.match(/\Ahttp/)
          RestClient.proxy = proxy
        end

        @ip = @config['ip'] = ip

        unless @token
          resp = auth
          @admins = @config['admins'] = [ resp['email'] ]
          @cloud = @config['cloud'] = resp['cloud']
          @name = @config['name'] = resp['name']
          @token = @config['token'] = resp['auth-token']
          # replace the resource with one that includes the auth token
          @client = resource
        end

        update_dns
      end

      # used if you want to work in offline mode
      def vcap_me
        @admins = @config['admins'] = [ "admin@vcap.me" ]
        @cloud = @config['cloud'] = "vcap.me"
        @name = @config['name'] = ""
      end

      # POST /api/v1/micro/token
      #   cloud - the common domain for the micro cloud (ie "cloudfoundry.me")
      #   name - the cloud specific domain for the micro cloud (ie "martin")
      #   Request body:
      #     {"nonce": "ethic-paper-thin"}
      #   Response:
      #     200 - nonce redeemed
      #       {"auth-token" : "HAqyzvZsK8uQLRlaFESmadKiD1dTkGhy",
      #        "name":"martin",
      #        "cloud":"cloudfoundry.me",
      #        "email":"martin@englund.nu"}
      #     403 - nonce rejected / unknown cloud or host
      #       no defined body
      def auth
        path = "/token"
        payload = Yajl::Encoder.encode({"nonce" => @nonce})
        response = @client[path].post(payload)
        resp = Yajl::Parser.new.parse(response)
        resp
      rescue RestClient::Forbidden => e
        puts "\nNotice: token rejected!"
        raise e
      end

      # PUT /api/v1/micro/clouds/{domain}/{name}/dns
      #   domain - the common domain for the micro cloud (ie "cloudfoundry.me")
      #   name - the cloud specific domain for the micro cloud (ie "martin")
      #   Request headers:
      #     Auth-Token: dsNqjhk48eSDdowr7x98BDwfn8hTxIfr
      #   Request body:
      #     {"address": "1.2.3.4"}
      #   Response:
      #     202 - new address accepted
      #       no defined body
      #     304 - address has not changed
      #       no defined body
      #     403 - bad auth token / unknown cloud or host
      #       no defined body
      def update_dns
        payload = Yajl::Encoder.encode({:address => @ip})
        @client["/clouds/#{@cloud}/#{@name}/dns"].put(payload)
      rescue RestClient::Forbidden => e
        puts "Notice: authorization token has expired"
        raise e
      rescue RestClient::NotModified
        # do nothing
      end

      def update_ip(ip)
        @ip = @config['ip'] = ip
        save
        update_dns
      end

      def subdomain
        [@name, @cloud].compact.join(".") # compact in case @name is nil
      end

      def save
        File.open(@config_file, 'w') do |f|
          Yajl::Encoder.encode(@config, f)
        end
      end

    end
  end
end
