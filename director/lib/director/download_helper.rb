module Bosh::Director
  module DownloadHelper
    require 'net/http'
    require 'timeout'
    require 'uri'

    ##
    # Downloads a remote file
    #
    # @param [String] resource Resource name to be logged
    # @param [String] remote_file Remote file to download
    # @param [String] local_file Local file to store the downloaded file
    # @raise [Bosh::Director::ResourceNotFound] If remote file is not found
    # @raise [Bosh::Director::ResourceError] If there's a network problem
    def download_remote_file(resource, remote_file, local_file)
      @logger.info("Downloading remote #{resource} from #{remote_file}") if @logger
      uri = URI.parse(remote_file)
      Net::HTTP.start(uri.host, uri.port, 
                      :use_ssl => uri.scheme == 'https',
                      :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
        http.request_get(uri.request_uri) do |response|
          unless response.kind_of? Net::HTTPSuccess
            @logger.error("Downloading remote #{resource} from #{remote_file} failed: #{response.message}") if @logger
            if response.kind_of? Net::HTTPNotFound 
              raise ResourceNotFound, "No #{resource} found at `#{remote_file}'."
            else
              raise ResourceError, "Downloading remote #{resource} failed. Check task debug log for details."
            end
          end
            
          File.open(local_file, 'wb') do |file|
            response.read_body do |chunk|
              file.write(chunk)
            end
          end
        end
      end       
    rescue URI::Error, SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError,
           Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      @logger.error("Downloading remote #{resource} from #{remote_file} failed: #{e.inspect}") if @logger
      raise ResourceError, "Downloading remote #{resource} failed. Check task debug log for details."
    end
  end
end