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

      # disable use of proxy when URI domain is in no_proxy
      if uri_matches_noproxy?(uri)
        proxy.host = nil
      end

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

    def uri_matches_noproxy?(uri)
      no_proxy = get_noproxy
      no_proxy.each do |no_proxy_domain|
        # remove leading dot if there is one in the no_proxy_domain
        no_proxy_domain.sub(/^\./,'')
        if uri.host.end_with?(no_proxy_domain)
          return true
        end
      end
      false
    end

    def get_noproxy
      noproxy = ENV['no_proxy']

      return [] unless noproxy

      noproxy.split(',')
    end

    NullUri = Struct.new(:host, :port, :user, :password)
  end
end
