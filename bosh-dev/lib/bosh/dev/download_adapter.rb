require 'net/http'
require 'uri'

module Bosh::Dev
  class DownloadAdapter
    def download(uri, write_path)
      uri = URI(uri)
      download_file(uri, write_path)

      File.expand_path(write_path)
    end

    private

    def download_file(uri, write_path)
      proxy = ENV['http_proxy'] ? URI.parse(ENV['http_proxy']) : NullUri.new

      Net::HTTP.start(uri.host, uri.port, proxy.host, proxy.port) do |http|
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

    NullUri = Struct.new(:host, :port)
  end
end
