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
      Net::HTTP.start(uri.host) do |http|
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
  end
end