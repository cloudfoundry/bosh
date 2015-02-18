module Bosh
  module Director
    module Api
      class RouteConfiguration
        def initialize(config)
          @config = config
        end

        def controllers
          director_app = Bosh::Director::App.new(@config)
          controllers = {}
          controllers['/info'] = Bosh::Director::Api::Controllers::InfoController.new identity_provider
          controllers['/tasks'] = Bosh::Director::Api::Controllers::TasksController.new identity_provider
          controllers['/backups'] = Bosh::Director::Api::Controllers::BackupsController.new identity_provider
          controllers['/deployments'] = Bosh::Director::Api::Controllers::DeploymentsController.new identity_provider
          controllers['/packages'] = Bosh::Director::Api::Controllers::PackagesController.new identity_provider
          controllers['/releases'] = Bosh::Director::Api::Controllers::ReleasesController.new identity_provider
          controllers['/resources'] = Bosh::Director::Api::Controllers::ResourcesController.new(
            identity_provider,
            Bosh::Director::Api::ResourceManager.new(director_app.blobstores.blobstore)
          )
          controllers['/resurrection'] = Bosh::Director::Api::Controllers::ResurrectionController.new identity_provider
          controllers['/stemcells'] = Bosh::Director::Api::Controllers::StemcellsController.new identity_provider
          controllers['/task'] = Bosh::Director::Api::Controllers::TaskController.new identity_provider
          controllers['/users'] = Bosh::Director::Api::Controllers::UsersController.new identity_provider
          controllers['/compiled_package_groups'] = Bosh::Director::Api::Controllers::CompiledPackagesController.new(
            identity_provider,
            Bosh::Director::Api::CompiledPackageGroupManager.new
          )
          controllers['/locks'] = Bosh::Director::Api::Controllers::LocksController.new identity_provider
          controllers
        end

        private

        def identity_provider
          @identity_provider ||= begin
            user_management = @config.hash['user_management']

            if user_management && user_management['provider'] == 'uaa'
              Bosh::Director::Api::UAAIdentityProvider.new
            else
              Bosh::Director::Api::LocalIdentityProvider.new Bosh::Director::Api::UserManager.new
            end
          end
        end
      end
    end
  end
end


