require 'net/http'
require 'uri'

module Bosh::Dev
  class DownloadAdapter
    def initialize(logger)
      @logger = logger
    end

    def download(uri, write_path)
      @logger.info("Downloading #{uri} to #{write_path}")
      FileUtils.mkdir_p(File.dirname(write_path))
      download_file(URI(uri), write_path)
      File.expand_path(write_path)
    end

    private

    def download_file(uri, write_path)
      proxy = ENV['http_proxy'] ? URI.parse(ENV['http_proxy']) : NullUri.new

      proxy = NullUri.new if bypass_proxy?(uri)

      Net::HTTP.start(uri.host, uri.port, proxy.host, proxy.port, proxy.user, proxy.password) do |http|
        http.request_get(uri.request_uri) do |response|
          raise "remote file '#{uri}' not found" if response.kind_of? Net::HTTPNotFound
          write_response(response, write_path)
        end
      end
    end

    def write_response(response, write_path)
      File.open(write_path, 'wb') do |file|
        response.read_body do |chunk|
          file.write(chunk)
        end
      end
    end

    def bypass_proxy?(uri)
      uris = bypass_proxy_uris
      uris.each do |domain|
        if uri.host.end_with?(clean_uri(domain))
          return true
        end
      end
      false
    end

    def bypass_proxy_uris
      uris = ENV['no_proxy']

      return [] unless uris

      uris.split(',')
    end

    def clean_uri(uri)
      uri.sub(/^\./,'')
      uri.gsub(/\s/,'')
    end

    NullUri = Struct.new(:host, :port, :user, :password)
  end
end
