require 'net/http'
require 'uri'

module Bosh::Dev
  class DownloadAdapter
    def download(uri, write_path)
      uri = URI(uri)
      Net::HTTP.start(uri.host) do |http|
        http.request_get(uri.request_uri) do |response|
          raise "remote file '#{uri}' not found" if response.kind_of? Net::HTTPNotFound

          File.open(write_path, 'wb') do |file|
            response.read_body do |chunk|
              file.write(chunk)
            end
          end
        end
      end
    end
  end
end