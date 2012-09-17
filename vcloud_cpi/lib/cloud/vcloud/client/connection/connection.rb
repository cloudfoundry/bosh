require 'base64'
require 'rest_client'

module VCloudCloud
  module Client
    module Connection
      class Connection
        SECURITY_CHECK = '/cloud/security_check'
        ACCEPT = 'application/*+xml;version=5.1'

        def initialize(hostname_port, organization, request_timeout = nil,
            rest_client = nil, site = nil, file_uploader = nil)
          @organization = organization
          @logger = Config.logger
          @rest_logger = Config.rest_logger
          @rest_throttle = Config.rest_throttle
          rest_client = RestClient unless rest_client
          rest_client.log = @rest_logger
          request_timeout = 60 unless request_timeout
          @site = site.nil? ? rest_client::Resource.new(hostname_port,
            :timeout => request_timeout) : site
          @file_uploader = file_uploader.nil? ? FileUploader : file_uploader
        end

        def connect(username, password)
          login = "#{username}@#{@organization}"
          login_password = "#{login}:#{password}"
          auth_header_value = "Basic #{Base64.encode64(login_password)}"
          response = @site['/api/sessions'].post(
            {:Authorization=>auth_header_value, :Accept=>ACCEPT})
          @logger.debug(response)
          @cookies = response.cookies
          unless @cookies["vcloud-token"].gsub!("+", "%2B").nil?
            @logger.debug("@cookies: #{@cookies.inspect}.")
          end
          VCloudCloud::Client::Xml::WrapperFactory.wrap_document(response)
        end

        # GET an object from REST and return the unmarshalled object
        def get(destination)
          @rest_logger.debug "#{__method__.to_s.upcase} #{delay}\t " +
                             "#{self.class.get_href(destination)}"
          sleep(delay)
          response = @site[get_nested_resource(destination)].get({
              :Accept=>ACCEPT,
              :cookies=>@cookies
          })
          @rest_logger.debug(response)
          Xml::WrapperFactory.wrap_document(response)
        end

        def post(destination, data, content_type = '*/*')
          @rest_logger.debug "#{__method__.to_s.upcase} #{delay}\t " +
                             "#{self.class.get_href(destination)}"
          sleep(delay)
          @rest_logger.debug("Warning: content type not specified. " +
                             " Default to '*/*'") if content_type == '*/*'
          @rest_logger.debug("#{__method__.to_s.upcase} data:#{data.to_s}")
          response = @site[get_nested_resource(destination)].post(data.to_s, {
              :Accept=>ACCEPT,
              :cookies=>@cookies,
              :content_type=>content_type
          })
          raise ApiRequestError if response.respond_to?(:code) &&
            response.code.to_i >= 400
          @rest_logger.debug(response)
          Xml::WrapperFactory.wrap_document(response)
        end

        def put(destination, data, content_type = '*/*')
          @rest_logger.debug "#{__method__.to_s.upcase} #{delay}\t " +
                             "#{self.class.get_href(destination)}"
          sleep(delay)
          @rest_logger.debug("Warning: content type not specified. " +
                             " Default to '*/*'") unless content_type
          @rest_logger.debug("#{__method__.to_s.upcase} data:#{data.to_s}")
          response = @site[get_nested_resource(destination)].put(data.to_s, {
              :Accept=>ACCEPT,
              :cookies=>@cookies,
              :content_type=>content_type
          })
          raise ApiRequestError if response.respond_to?(:code) &&
            response.code.to_i >= 400
          @rest_logger.debug((response && !response.strip.empty?) ?
            response : "Received empty response.")
          if response && !response.strip.empty?
            Xml::WrapperFactory.wrap_document(response)
          else
            nil
          end
        end

        def delete(destination)
          @rest_logger.debug "#{__method__.to_s.upcase} #{delay}\t " +
                             "#{self.class.get_href(destination)}"
          sleep(delay)
          response = @site[get_nested_resource(destination)].delete({
              :Accept=>ACCEPT,
              :cookies=>@cookies
          })
          @rest_logger.debug(response)
          if response && !response.strip.empty?
            Xml::WrapperFactory.wrap_document(response)
          else
            nil
          end
        end

        # The PUT method in rest-client can't handle large files because it
        # doesn't use the underlying Net::HTTP body_stream attribute.
        # Without that, it won't use chunked transfer-encoding.  It also reads
        # in the whole file at once.
        def put_file(destination, file)
          href = self.class.get_href(destination)
          @rest_logger.debug "#{__method__.to_s.upcase}\t#{href}"
          response = @file_uploader.upload(href, file, @cookies)
          response
        end

        private
        def log_exceptions(ex)
          if ex.is_a? RestClient::Exception
            @logger.error("HTTP Code: #{ex.http_code}")
            @logger.error("HTTP Body: #{ex.http_body}")
            @logger.error("Message: #{ex.message}")
            @logger.error("Response: #{ex.response}")
          end
        end

        def delay()
          @rest_throttle['min'] + rand(@rest_throttle['max'] -
            @rest_throttle['min'])
        end

        def get_nested_resource(destination)
          href = self.class.get_href(destination)
          if href.is_a?(String)
            URI.parse(href).path
          else
            raise "href is not a string: #{href.inspect} #{destination}."
          end
        end

        class << self
          def get_href(destination)
            if destination.is_a?(Xml::Wrapper) && destination.href
              destination.href
            else
              destination
            end
          end
        end
      end

    end
  end
end
