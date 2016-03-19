#feature not supported for ruby < 2.0.0
begin
  require 'syslog/logger'
rescue LoadError
  puts "Failed to load Syslog::Logger. Ruby version #{RUBY_VERSION} not supported. Use RUBY_VERSION >= 2.0.0"
end

require 'socket'

module Bosh::Director
  module Api
    module Extensions
      module SyslogRequestLogger
        DESIRED_HEADERS = [
          'HTTP_HOST',
          'HTTP_X_REAL_IP',
          'HTTP_X_FORWARDED_FOR',
          'HTTP_X_FORWARDED_PROTO',
          'HTTP_USER_AGENT',
          'HTTP_X_BOSH_UPLOAD_REQUEST_TIME'
        ]

        def log_request_to_syslog

          before do
            # TODO: the ruby version checks can be removed when we stop testing w 1.9
            if @config.log_access_events_to_syslog && RUBY_VERSION.to_i > 1
              @timestamp = Time.now.utc
            end
          end

          after do
            if @config.log_access_events_to_syslog && RUBY_VERSION.to_i > 1
              request_hash = {'type' => 'api'}

              request_hash['timestamp'] = @timestamp

              auth_type = current_user.nil? ? 'none' : identity_provider.client_info['type']
              request_hash['auth'] = {'type' => auth_type}
              request_hash['auth']['user'] = @user.username if @user && @user.username
              request_hash['auth']['client'] = @user.client if @user && @user.client

              request_hash['http'] = {
                'verb' => request.request_method,
                'path' => request.path
              }
              request_hash['http']['query'] = request.query_string unless request.query_string.blank?
              request_hash['client'] = {'ip' => request.ip}
              response_status = response.status
              request_hash['http']['status'] = {'code' => response_status}
              request_hash['http']['status']['reason'] = response.body.join('')[0...500] if response_status >= 400

              request_hash['http']['headers'] = request.env
                                                  .select { |key, _| DESIRED_HEADERS.include?(key) }
                                                  .collect { |key, value| [key.sub(/^HTTP_/, ''), value] }

              request_hash['component'] = {'name' => 'director'}
              request_hash['component']['version'] = Bosh::Director::VERSION
              request_hash['component']['port'] = @config.port
              request_hash['component']['hostname'] = Socket.gethostname
              request_hash['component']['ips'] = Socket.ip_address_list
                        .reject { |addr| !addr.ip? || addr.ipv4_loopback? || addr.ipv6_loopback? }
                        .map { |addr| addr.ip_address }

              Syslog::Logger.new('bosh.director').info(JSON.dump(request_hash))
            end
          end
        end
      end
    end
  end
end

