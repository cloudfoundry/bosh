require 'yajl'

module VCAP
  module Micro
    class Proxy

      attr_reader :url

      PROXY_CONFIG = "/var/vcap/micro/proxy.json"
      def initialize(config_file=PROXY_CONFIG)
        @config_file = config_file
        @url = ""
        load if configured?
      end

      # TODO do a better job of validating the proxy, e.g. try accessing
      # cf.com thought it
      def url=(url)
        if url.match(/^none$/)
          @url = ""
        elsif url.match(/^http:\/\//)
          @url = url
        else
          @url = nil
        end
      end

      def name
        @url.empty? ? "none" : @url
      end

      def configured?
        File.exist?(@config_file)
      end

      def load
        File.open(@config_file) do |f|
          config = Yajl::Parser.parse(f)
          @url = config['url']
        end
      end

      def save
        File.open(@config_file, 'w') do |f|
          config = {}
          config['url'] = @url
          Yajl::Encoder.encode(config, f)
        end
      end
    end
  end
end
