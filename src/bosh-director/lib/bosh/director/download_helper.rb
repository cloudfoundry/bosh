require 'net/http'
require 'timeout'
require 'uri'

module Bosh::Director
  module DownloadHelper
    # Downloads a remote file
    # @param [String] resource Resource name to be logged
    # @param [String] remote_file Remote file to download
    # @param [String] local_file Local file to store the downloaded file
    # @raise [Bosh::Director::ResourceNotFound] If remote file is not found
    # @raise [Bosh::Director::ResourceError] If there's a network problem
    def download_remote_file(resource, remote_file, local_file, num_redirects = 0)
      remote_file_redacted = Bosh::Director::Redactor.new.redact_basic_auth(remote_file)
      @logger&.info("Downloading remote #{resource} from #{remote_file_redacted}")
      uri = URI.parse(remote_file)
      req = Net::HTTP::Get.new(uri)

      if uri.user && uri.password
        req.basic_auth uri.user, uri.password
      end

      Net::HTTP.start(uri.host, uri.port, :ENV,
                      :use_ssl => uri.scheme == 'https') do |http|
        http.request req do |response|
          case response
            when Net::HTTPSuccess
              File.open(local_file, 'wb') do |file|
                response.read_body do |chunk|
                  file.write(chunk)
                end
              end

            when Net::HTTPFound, Net::HTTPMovedPermanently
              raise ResourceError, "Too many redirects at '#{remote_file_redacted}'." if num_redirects >= 9

              location = response.header['location']
              raise ResourceError, "No location header for redirect found at '#{remote_file_redacted}'." if location.nil?

              location = URI.join(uri, location).to_s
              download_remote_file(resource, location, local_file, num_redirects + 1)

            when Net::HTTPNotFound
              @logger&.error("Downloading remote #{resource} from #{remote_file_redacted} failed: #{response.message}")
              raise ResourceNotFound, "No #{resource} found at '#{remote_file_redacted}'."

            else
              @logger&.error("Downloading remote #{resource} from #{remote_file_redacted} failed: #{response.message}")
              raise ResourceError, "Downloading remote #{resource} failed. Check task debug log for details."
          end
        end
      end
    rescue URI::Error, SocketError, ::Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError,
           Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      @logger&.error("Downloading remote #{resource} from #{remote_file_redacted} failed: #{e.inspect}")
      raise ResourceError, "Downloading remote #{resource} failed. Check task debug log for details."
    end
  end
end
