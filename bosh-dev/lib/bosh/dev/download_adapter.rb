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
        http.read_timeout = 300

        begin
          File.open(write_path, 'wb') do |file|
            tries = 0
            begin
              headers = {}
              headers['Range'] = "bytes=#{file.tell}-" if tries > 0
              http.request_get(uri.request_uri, headers) do |response|
                raise "remote file '#{uri}' not found" if response.kind_of? Net::HTTPNotFound

                response.read_body do |chunk|
                  file.write(chunk)
                end
              end
            rescue Timeout::Error => e
              @logger.info("Download of #{uri} timed out.")

              raise e unless tries < 3
              tries += 1

              @logger.debug("Retrying ...")
              retry
            end
          end
        rescue Exception => e
          File.delete(write_path) if File.exist?(write_path)
          raise e
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
