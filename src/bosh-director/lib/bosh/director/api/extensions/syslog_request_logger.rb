require 'socket'

module Bosh::Director
  module Api
    module Extensions
      module SyslogRequestLogger

        DESIRED_HEADERS = %w(
          HTTP_HOST
          HTTP_X_REAL_IP
          HTTP_X_FORWARDED_FOR
          HTTP_X_FORWARDED_PROTO
          HTTP_USER_AGENT
          HTTP_X_BOSH_UPLOAD_REQUEST_TIME
        )

        def log_request_to_syslog
          after do
            if @config.log_access_events_to_syslog && SyslogHelper.syslog_supported
              header_string = ''
              filtered_headers = request.env.select { |key, _| DESIRED_HEADERS.include?(key) }
                                     .collect { |key, value| [key.sub(/^HTTP_/, ''), value] }
              filtered_headers.each do |header_set|
                header_string += header_set[0] + "\=" + header_set[1] + "&"
              end
              header_string = header_string[0..-2] if !header_string.empty?

              filtered_ip_list = Socket.ip_address_list
                        .reject { |addr| !addr.ip? || addr.ipv4_loopback? || addr.ipv6_loopback? }
                        .map { |addr| addr.ip_address }

              cef_version = 0
              device_vendor = 'CloudFoundry'
              device_product = 'BOSH'
              device_version = @config.version
              signature_id = 'director_api'
              name = "#{request.path}"
              severity = response.status >= 400 ?  7 : 1

              extension = ''
              if @user
                extension += "duser=#{@user.username} " if @user.username
                extension += "requestClientApplication=#{@user.client} " if @user.client
              end

              extension += "requestMethod=#{request.request_method} src=#{request.ip} spt=#{@config.port}" +
                  " shost=#{Socket.gethostname}" +
                  " cs1=#{filtered_ip_list.join(',')} cs1Label=ips" +
                  " cs2=#{header_string} cs2Label=httpHeaders" +
                  " cs3=#{current_user.nil? ? 'none' : identity_provider.client_info['type']} cs3Label=authType" +
                  " cs4=#{response.status} cs4Label=responseStatus"
              if response.status >= 400
                extension += " cs5=#{response.body.join('')[0...500].strip} cs5Label=statusReason"
              end

              cef_log = 'CEF:%i|%s|%s|%s|%s|%s|%s|%s' % [cef_version, device_vendor, device_product,
                                                         device_version, signature_id, name, severity, extension]
              cef_log_encoded = cef_log.force_encoding(Encoding::UTF_8)

              syslog(:info, cef_log_encoded)
            end
          end
        end
      end
    end
  end
end

