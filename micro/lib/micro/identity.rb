require 'rest-client'
require 'yajl'

module VCAP
  module Micro
    class Identity
      attr_accessor :admins, :ip, :nonce, :version
      attr_reader :name, :cloud, :version, :api_host, :proxy, :latest_version

      DEFAULT_API_HOST = "mcapi.cloudfoundry.com"
      URL = "https://%s/api/v1/micro"
      MICRO_CONFIG = "/var/vcap/micro/micro.json"
      CLOUD = "cloudfoundry.me"

      def initialize(proxy, config_file=MICRO_CONFIG)
        @proxy = proxy
        @config_file = config_file
        load_config if configured?
        @config ||= {}
        @api_host ||= DEFAULT_API_HOST
        @client = resource
        @logger = Console.logger
        @version = VCAP::Micro::Version::VERSION
      end

      def configured?
        File.exist?(@config_file)
      end

      def clear
        FileUtils.rm_f(@config_file)
        @config = {}
        @name = @config['name'] = nil
        @cloud = @config['cloud'] = nil
        @admins = @config['admins'] = nil
        @ip = @config['ip'] = nil
        @token = @config['token'] = nil
        @api_host = @config['api_host'] = DEFAULT_API_HOST
      end

      def load_config
        File.open(@config_file) do |f|
          @config = Yajl::Parser.parse(f)
          @name = @config['name']
          @cloud = @config['cloud']
          @admins = @config['admins']
          @ip = @config['ip']
          @token = @config['token']
          @api_host = @config['api_host']
        end
      end

      def url
        URL % @api_host
      end

      def resource
        headers = { :content_type => 'application/json' }
        headers["Auth-Token"] = @token if @token
        RestClient::Resource.new(url, :headers => headers)
      end

      def update_api_host(host)
        @api_host = @config['api_host'] = host
        @client = resource
        save
      end

      def install(ip)
        unless @proxy.url.empty?
          RestClient.proxy = @proxy.url
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

        save
        update_dns
      end

      # used if you want to work in offline mode
      def offline(ip, domain, admin)
        @logger.info("configuring offline mode with: #{domain}")
        @admins = @config['admins'] = [ admin ]
        name, cloud = domain.split(/\./, 2)
        @cloud = @config['cloud'] = cloud
        @name = @config['name'] = name
        @ip = @config['ip'] = ip
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
      #     403 - nonce expired
      #     404 - bogus nonce
      #     409 - used nonce
      def auth
        path = "/token"
        payload = Yajl::Encoder.encode({"nonce" => @nonce})
        json = @client[path].post(payload)
        response = Yajl::Parser.new.parse(json)
        @logger.debug("raw response: #{json.inspect}")
        if response
          values = response.collect {|k,v| "#{k} = #{v}"}.join("\n")
          @logger.info("got following response for token: #{@nonce}\n#{values}")
        end
        response
      rescue Errno::ECONNREFUSED => e
        warn("connection refused", e)
      rescue Errno::ETIMEDOUT => e
        warn("connection timed out", e)
      rescue Errno::ECONNRESET => e
        # TODO this might be eternal if they are behind a crappy proxy
        warn("connection reset, your proxy might be interfering", e)
      rescue RestClient::Found => e
        warn("page redirected - your proxy is interfering: switch to NAT", e)
      rescue RestClient::Forbidden => e
        warn("authorization token has expired", e)
      rescue RestClient::ResourceNotFound => e
        warn("no such authorization token", e)
      rescue RestClient::Conflict => e
        warn("authorization token already used", e)
      end

      def warn(msg, exception)
        @logger.warn(msg)
        $stderr.puts "\nNotice: #{msg}"
        raise exception
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
      def update_dns(silent=false)
        # only update if there is a auth token, i.e. a cloudfoundry.me domain is used
        return unless @token

        pbar = ProgressBar.new("updating DNS", Watcher::TTL) unless silent

        payload = Yajl::Encoder.encode({:address => @ip})
        json = @client["/clouds/#{@cloud}/#{@name}/dns"].put(payload)
        response = Yajl::Parser.new.parse(json)

        if response
          # latest is the file name - micro-1.0.0_rc2.tgz
          @latest_version = Version.file2version(response["latest"])
          @version = response["version"] if response["version"]
          values = response.collect {|k,v| "#{k} = #{v}"}.join("\n")
          @logger.info("got following response from DNS update:\n#{values}")
        end

        i = 1
        while i <= Watcher::TTL + 5 # add a little fudge to avoid a warning
          break if Network.lookup(subdomain) == @ip
          pbar.inc unless silent
          sleep(1)
          i += 1
        end

      rescue RestClient::Forbidden
        @logger.error("DNS update forbidden for #{@name}.#{@cloud} -> #{@ip} using #{@token}")
        $stderr.puts("DNS update failed!".red)
        $stderr.puts("You need to install a new token (option 4 on the console menu)")
      rescue SocketError => e
        @logger.error("DNS update failed for #{@name}.#{@cloud} -> #{@ip}: #{e}")
        $stderr.puts("DNS update failed: could not lookup #{@name}.#{@cloud}".red)
      rescue OpenSSL::SSL::SSLError => e
        @logger.error("DNS update failed for #{@name}.#{@cloud} -> #{@ip}: #{e}")
        $stderr.puts("DNS update failed: could initiate SSL connection #{@name}.#{@cloud}".red)
      rescue RestClient::MethodNotAllowed
        # do nothing
      rescue RestClient::NotModified
        # do nothing
      ensure
        return if silent || @token.nil?
        pbar.finish

        if Network.lookup(subdomain) == @ip
          say("done".green)
        elsif Network.ext_lookup(subdomain) == @ip
          say("External DNS updated, cached information is still being served".yellow)
        else
          say("DNS still synchronizing, continuing after waiting #{Watcher::TTL} seconds".yellow)
        end
      end

      def update_ip(ip, silent=false)
        @ip = @config['ip'] = ip
        save
        update_dns(silent)
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
