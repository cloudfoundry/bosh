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
              request_hash['http'] = {'verb' => request.request_method, 'path' => request.path_info}

              request_hash['http']['query'] = request.query_string unless request.query_string.blank?
              request_hash['client'] = {'ip' => request.ip}
              response_status = response.status
              request_hash['http']['status'] = {'code' => response_status}
              request_hash['http']['status']['reason'] = response.body.join('')[0...500] if response_status >= 400

              request_hash['http']['headers'] = request.env
                                                  .select { |k, v| k.start_with? 'HTTP_' }
                                                  .collect { |key, val| [key.sub(/^HTTP_/, ''), val] }
              request_hash['component'] = {'name' => 'director'}
              request_hash['component']['version'] = Bosh::Director::VERSION
              request_hash['component']['port'] = @config.port
              request_hash['component']['hostname'] = Socket.gethostname

              Syslog::Logger.new('bosh.director').info(JSON.dump(request_hash))
            end
          end
        end
      end
    end
  end
end

