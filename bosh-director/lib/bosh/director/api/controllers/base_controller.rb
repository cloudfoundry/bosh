module Bosh::Director
  module Api
    module Controllers
      class BaseController < Sinatra::Base
        PUBLIC_URLS = %w(/info)

        include ApiHelper
        include Http
        include DnsHelper

        def initialize(*_)
          super
          @deployment_manager = DeploymentManager.new
          @backup_manager = BackupManager.new
          @instance_manager = InstanceManager.new
          @resurrector_manager = ResurrectorManager.new
          @problem_manager = ProblemManager.new
          @property_manager = PropertyManager.new
          @resource_manager = ResourceManager.new
          @release_manager = ReleaseManager.new
          @snapshot_manager = SnapshotManager.new
          @stemcell_manager = StemcellManager.new
          @task_manager = TaskManager.new
          @user_manager = UserManager.new
          @vm_state_manager = VmStateManager.new
          @logger = Config.logger
        end

        mime_type :tgz, 'application/x-compressed'

        def self.consumes(*types)
          types = Set.new(types)
          types.map! { |t| mime_type(t) }

          condition do
            types.include?(request.content_type)
          end
        end

        def authenticate(user, password)
          if @user_manager.authenticate(user, password)
            @user = user
            true
          else
            false
          end
        end

        helpers ControllerHelpers

        before do
          auth_provided = %w(HTTP_AUTHORIZATION X-HTTP_AUTHORIZATION X_HTTP_AUTHORIZATION).detect do |key|
            request.env.has_key?(key)
          end

          protected! if auth_provided || !PUBLIC_URLS.include?(request.path_info)
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
