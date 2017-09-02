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
          controllers['/backups'] = Bosh::Director::Api::Controllers::BackupsController.new(@config)
          controllers['/cleanup'] = Bosh::Director::Api::Controllers::CleanupController.new(@config)
          controllers['/restore'] = Bosh::Director::Api::Controllers::RestoreController.new(@config)
          controllers['/cloud_configs'] = Bosh::Director::Api::Controllers::CloudConfigsController.new(@config)
          controllers['/runtime_configs'] = Bosh::Director::Api::Controllers::RuntimeConfigsController.new(@config)
          controllers['/cpi_configs'] = Bosh::Director::Api::Controllers::CpiConfigsController.new(@config)
          controllers['/deployments'] = Bosh::Director::Api::Controllers::DeploymentsController.new(@config)
          controllers['/disks'] = Bosh::Director::Api::Controllers::DisksController.new(@config)
          controllers['/orphan_disks'] = Bosh::Director::Api::Controllers::OrphanDisksController.new(@config)
          controllers['/info'] = Bosh::Director::Api::Controllers::InfoController.new(@config)
          controllers['/locks'] = Bosh::Director::Api::Controllers::LocksController.new(@config)
          controllers['/packages'] = Bosh::Director::Api::Controllers::PackagesController.new(@config)
          controllers['/releases'] = Bosh::Director::Api::Controllers::ReleasesController.new(@config)
          controllers['/resources'] = Bosh::Director::Api::Controllers::ResourcesController.new(
            @config,
            Bosh::Director::Api::ResourceManager.new(director_app.blobstores.blobstore)
          )
          controllers['/resurrection'] = Bosh::Director::Api::Controllers::ResurrectionController.new(@config)
          controllers['/stemcells'] = Bosh::Director::Api::Controllers::StemcellsController.new(@config)
          controllers['/task'] = Bosh::Director::Api::Controllers::TaskController.new(@config)
          controllers['/tasks'] = Bosh::Director::Api::Controllers::TasksController.new(@config)
          controllers['/events'] = Bosh::Director::Api::Controllers::EventsController.new(@config)
          controllers['/vms'] = Bosh::Director::Api::Controllers::VmsController.new(@config)
          controllers
        end
      end
    end
  end
end


