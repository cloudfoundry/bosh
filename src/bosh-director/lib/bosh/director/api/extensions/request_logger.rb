require 'socket'

module Bosh::Director
  module Api
    module Extensions
      module RequestLogger
        DESIRED_HEADERS = %w[
          HTTP_HOST
          HTTP_X_REAL_IP
          HTTP_X_FORWARDED_FOR
          HTTP_X_FORWARDED_PROTO
          HTTP_USER_AGENT
          HTTP_X_BOSH_UPLOAD_REQUEST_TIME
        ].freeze

        def log_request_to_auditlog
          after do
            return unless @config.log_access_events

            header_string = RequestLogger.create_header(request)

            filtered_ip_list = Socket.ip_address_list
                                     .reject { |addr| !addr.ip? || addr.ipv4_loopback? || addr.ipv6_loopback? }
                                     .map(&:ip_address)

            cef_version = 0
            device_vendor = 'CloudFoundry'
            device_product = 'BOSH'
            device_version = @config.version
            signature_id = 'director_api'
            name = request.path.to_s
            severity = response.status >= 400 ? 7 : 1

            extension_config = {
              request: request,
              filtered_ip_list: filtered_ip_list,
              header_string: header_string,
              current_user: current_user,
              identity_provider: identity_provider,
              response: response,
            }
            extension = RequestLogger.create_extension(@user, @config, extension_config)

            cef_log = "CEF:#{cef_version}|#{device_vendor}|#{device_product}|#{device_version}|#{signature_id}|"\
                      "#{name}|#{severity}|#{extension}"
            cef_log_encoded = cef_log.force_encoding(Encoding::UTF_8)

            @audit_logger.info(cef_log_encoded)
          end
        end

        def self.create_header(request)
          header_string = ''
          filtered_headers = request.env.select { |key, _| DESIRED_HEADERS.include?(key) }
                                    .collect { |key, value| [key.sub(/^HTTP_/, ''), value] }
          filtered_headers.each do |header_set|
            header_string += "#{header_set[0]}=#{header_set[1]}&"
          end
          header_string = header_string[0..-2] unless header_string.empty?
          header_string
        end

        def self.create_extension(user, config, extension_config)
          extension = ''
          if user
            extension += "duser=#{user.username} " if user.username
            extension += "requestClientApplication=#{user.client} " if user.client
          end

          extension += "requestMethod=#{extension_config[:request].request_method}"\
            " src=#{extension_config[:request].ip}"\
            " spt=#{config.port}"\
            " shost=#{Socket.gethostname}"\
            " cs1=#{extension_config[:filtered_ip_list].join(',')} cs1Label=ips"\
            " cs2=#{extension_config[:header_string]} cs2Label=httpHeaders"\
            " cs3=#{extension_config[:current_user].nil? ? 'none' : extension_config[:identity_provider].client_info['type']}"\
            ' cs3Label=authType'\
            " cs4=#{extension_config[:response].status} cs4Label=responseStatus"
          if extension_config[:response].status >= 400
            extension += " cs5=#{extension_config[:response].body.join('')[0...500].strip} cs5Label=statusReason"
          end
          extension
        end
      end
    end
  end
end
