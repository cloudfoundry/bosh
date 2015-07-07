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

      open_http_connection(proxy, uri) do |http|
        http.read_timeout = 300
        File.open(write_path, 'wb') do |file|
          write_to_file(http, uri, file)
        end
      end
    rescue Exception => e
      File.delete(write_path) if File.exist?(write_path)
      raise e
    end

    def open_http_connection(proxy, uri, &block)
      tries = 0
      begin
        http = Timeout.timeout(60) do
          Net::HTTP.start(uri.host, uri.port, proxy.host, proxy.port, proxy.user, proxy.password)
        end
      rescue Timeout::Error => e
        @logger.info("Connecting to #{uri} timed out.")
        raise e unless tries < 3
        tries += 1
        @logger.debug("Retrying ...")
        retry
      end
      block.call(http)
    ensure
      http.finish() if defined?(http)
    end

    def write_to_file(http, uri, file)
      tries = 0
      begin
        headers = {}
        headers['Range'] = "bytes=#{file.tell}-" if tries > 0
        http.request_get(uri.request_uri, headers) do |response|
          unless response.kind_of? Net::HTTPSuccess
            raise "error #{response.code} while downloading '#{uri}'"
          end

          starting_byte = 0
          starting_byte = response.content_range.first if response['Content-Range']
          file.seek(starting_byte)
          file.truncate(starting_byte)
          if tries > 0
            @logger.info("Resuming download of #{uri} from #{starting_byte} bytes")
          end

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
