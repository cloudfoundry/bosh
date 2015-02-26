module Bosh
  module Director
    module Api
      class RouteConfiguration

        USER_MANAGEMENT_PROVIDERS = %w[uaa local]

        def initialize(config)
          @config = config
        end

        def controllers
          director_app = Bosh::Director::App.new(@config)
          controllers = {}
          controllers['/info'] = Bosh::Director::Api::Controllers::InfoController.new(identity_provider)
          controllers['/tasks'] = Bosh::Director::Api::Controllers::TasksController.new(identity_provider)
          controllers['/backups'] = Bosh::Director::Api::Controllers::BackupsController.new(identity_provider)
          controllers['/deployments'] = Bosh::Director::Api::Controllers::DeploymentsController.new(identity_provider)
          controllers['/packages'] = Bosh::Director::Api::Controllers::PackagesController.new(identity_provider)
          controllers['/releases'] = Bosh::Director::Api::Controllers::ReleasesController.new(identity_provider)
          controllers['/resources'] = Bosh::Director::Api::Controllers::ResourcesController.new(
            identity_provider,
            Bosh::Director::Api::ResourceManager.new(director_app.blobstores.blobstore)
          )
          controllers['/resurrection'] = Bosh::Director::Api::Controllers::ResurrectionController.new(identity_provider)
          controllers['/stemcells'] = Bosh::Director::Api::Controllers::StemcellsController.new(identity_provider)
          controllers['/task'] = Bosh::Director::Api::Controllers::TaskController.new(identity_provider)
          controllers['/users'] = Bosh::Director::Api::Controllers::UsersController.new(identity_provider)
          controllers['/compiled_package_groups'] = Bosh::Director::Api::Controllers::CompiledPackagesController.new(
            identity_provider,
            Bosh::Director::Api::CompiledPackageGroupManager.new
          )
          controllers['/locks'] = Bosh::Director::Api::Controllers::LocksController.new(identity_provider)
          controllers
        end

        private

        def identity_provider
          @identity_provider ||= begin
            # no fetching w defaults?
            user_management = @config.hash['user_management']
            user_management_provider = user_management['provider']

            unless USER_MANAGEMENT_PROVIDERS.include?(user_management_provider)
              raise ArgumentError,
                "Unknown user management provider '#{user_management_provider}', " +
                  "available providers are: #{USER_MANAGEMENT_PROVIDERS}"
            end
            if user_management_provider == 'uaa'
              Config.logger.debug("Director configured with 'uaa' user management provider")
              unless user_management['options'] && user_management['options']['key']
                raise ArgumentError, "Missing UAA secret key in user_management.options.key"
              end

              Bosh::Director::Api::UAAIdentityProvider.new(user_management['options']['key'])
            else
              Config.logger.debug("Director configured with 'local' user management provider")
              Bosh::Director::Api::LocalIdentityProvider.new(Bosh::Director::Api::UserManager.new)
            end
          end
        end
      end
    end
  end
end


