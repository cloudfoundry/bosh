module Bosh::Director
  module Api
    module Controllers
      class BaseController < Sinatra::Base
        include ApiHelper
        include Http
        include DnsHelper

        def initialize(config)
          super()
          @config = config
          @identity_provider = config.identity_provider
          @deployment_manager = DeploymentManager.new
          @backup_manager = BackupManager.new
          @instance_manager = InstanceManager.new
          @resurrector_manager = ResurrectorManager.new
          @problem_manager = ProblemManager.new(@deployment_manager)
          @property_manager = PropertyManager.new(@deployment_manager)
          @release_manager = ReleaseManager.new
          @snapshot_manager = SnapshotManager.new
          @stemcell_manager = StemcellManager.new
          @task_manager = TaskManager.new
          @user_manager = UserManager.new
          @vm_state_manager = VmStateManager.new
          @logger = Config.logger
        end

        mime_type :tgz,       'application/x-compressed'
        mime_type :multipart, 'multipart/form-data'

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

        def requires_authentication?
          true
        end

        before do
          auth_provided = %w(HTTP_AUTHORIZATION X-HTTP_AUTHORIZATION X_HTTP_AUTHORIZATION).detect do |key|
            request.env.has_key?(key)
          end

          if auth_provided
            begin
              @user = @identity_provider.corroborate_user(request.env)
            rescue AuthenticationError
            end
          end

          if requires_authentication? && @user.nil?
            response['WWW-Authenticate'] = 'Basic realm="BOSH Director"'
            throw(:halt, [401, "Not authorized\n"])
          end
        end

        after { headers('Date' => Time.now.rfc822) } # As thin doesn't inject date

        configure do
          set(:show_exceptions, false)
          set(:raise_errors, false)
          set(:dump_errors, false)
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
