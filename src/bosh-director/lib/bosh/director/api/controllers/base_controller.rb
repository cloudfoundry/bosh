module Bosh::Director
  module Api
    module Controllers
      class BaseController < Sinatra::Base
        include ApiHelper
        include Http
        include SyslogHelper

        def initialize(config)
          super()
          @config = config
          @logger = Config.logger
          @identity_provider = config.identity_provider
          @permission_authorizer = PermissionAuthorizer.new(config.get_uuid_provider)
          @backup_manager = BackupManager.new
          @restore_manager = RestoreManager.new
          @resurrector_manager = ResurrectorManager.new
          @release_manager = ReleaseManager.new
          @snapshot_manager = SnapshotManager.new
          @stemcell_manager = StemcellManager.new
          @task_manager = TaskManager.new
          @event_manager = EventManager.new(config.record_events)
        end

        register(Bosh::Director::Api::Extensions::SyslogRequestLogger)
        log_request_to_syslog

        register(Bosh::Director::Api::Extensions::Scoping)

        mime_type :tgz,       'application/x-compressed'
        mime_type :multipart, 'multipart/form-data'

        ROUTES_WITH_EXTENDED_TIMEOUT = ['/stemcells', '/releases', '/restore']

        attr_reader :identity_provider

        def self.consumes(*types)
          types = Set.new(types)
          types.map! { |t| mime_type(t) }

          condition do
            # Content-Type header may include charset or boundry info
            content_type = request.content_type || ''
            mime_type = content_type.split(';')[0]
            types.include?(mime_type)
          end
        end

        before do
          auth_provided = %w(HTTP_AUTHORIZATION X-HTTP_AUTHORIZATION X_HTTP_AUTHORIZATION).detect do |key|
            request.env.has_key?(key)
          end

          if auth_provided
            begin
              extended_token_timeout = ROUTES_WITH_EXTENDED_TIMEOUT.include?(request.path) &&
                request.media_type == mime_type(:multipart) &&
                request.request_method == 'POST'

              @user = identity_provider.get_user(request.env, extended_token_timeout: extended_token_timeout)
            rescue AuthenticationError
            end
          end

          if requires_authentication?
            response['WWW-Authenticate'] = 'Basic realm="BOSH Director"'
            if @user.nil?
              message = "Not authorized: '#{request.path}'\n"
              throw(:halt, [401, message])
            end
          end

          @current_context_id = request.env.fetch('HTTP_X_BOSH_CONTEXT_ID', '')

          if @current_context_id.length > 64
              raise ContextIdViolatedMax, "X-Bosh-Context-Id cannot be more than 64 characters in length"
          end
        end

        def requires_authentication?
          true
        end

        after { headers('Date' => Time.now.rfc822) } # As thin doesn't inject date

        configure do
          set(:show_exceptions, false)
          set(:raise_errors, false)
          set(:dump_errors, false)
        end

        not_found do
          status(404)
          "Endpoint '#{request.path}' not found. Please consider upgrading your director"
        end

        error do
          exception = request.env['sinatra.error']
          if exception.kind_of?(DirectorError)
            @logger.debug('Request failed, ' +
                            "response code: #{exception.response_code}, " +
                            "error code: #{exception.error_code}, " +
                            "error message: #{exception.message}")
            status(exception.response_code)
            error_payload = {
              'code' => exception.error_code,
              'description' => exception.message
            }
            json_encode(error_payload)
          else
            msg = ["#{exception.class} - #{exception.message}:"]
            msg.concat(exception.backtrace)
            @logger.error(msg.join("\n"))
            status(500)
          end
        end
      end
    end
  end
end
