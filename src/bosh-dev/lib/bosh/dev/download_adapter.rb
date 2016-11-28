require 'net/https'
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
      File.open(write_path, 'wb') do |file|
        write_to_file(uri, file)
      end
    rescue Exception => e
      File.delete(write_path) if File.exist?(write_path)
      raise e
    end

    def open_http_connection(proxy, uri, &block)
      tries = 0
      http = nil
      begin
        http = Timeout.timeout(60) do
          http_opts = {read_timeout: 300}
          if uri.scheme == 'https'
            http_opts = http_opts.merge({use_ssl: true})
          end
          Net::HTTP.start(uri.host, uri.port, proxy.host, proxy.port, proxy.user, proxy.password, http_opts)
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
      http.finish() unless http.nil?
    end

    def write_to_file(uri, file, redirects_remaining = 10)
      proxy = ENV['http_proxy'] ? URI.parse(ENV['http_proxy']) : NullUri.new
      proxy = NullUri.new if bypass_proxy?(uri)

      open_http_connection(proxy, uri) do |http|
        tries = 0
        begin
          headers = {}
          headers['Range'] = "bytes=#{file.tell}-" if tries > 0

          http.request_get(uri.request_uri, headers) do |response|
            if response.kind_of? Net::HTTPRedirection
              if redirects_remaining > 0
                return write_to_file(URI(response['location']), file, redirects_remaining - 1)
              else
                raise "infinite redirect loop while downloading '#{uri}'"
              end
            end
            unless response.kind_of? Net::HTTPSuccess
              err_msg = "error #{response.code} #{response.message} while downloading '#{uri}'"
              err_msg += ": #{response.body}" if response.body
              raise err_msg
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
