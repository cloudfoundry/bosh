require 'bosh/director/api/controllers/backups_controller'
require 'bosh/director/api/controllers/deployments_controller'
require 'bosh/director/api/controllers/packages_controller'
require 'bosh/director/api/controllers/info_controller'
require 'bosh/director/api/controllers/releases_controller'
require 'bosh/director/api/controllers/resources_controller'
require 'bosh/director/api/controllers/resurrection_controller'
require 'bosh/director/api/controllers/stemcells_controller'
require 'bosh/director/api/controllers/tasks_controller'
require 'bosh/director/api/controllers/users_controller'
require 'bosh/director/api/controllers/compiled_packages_controller'
require 'bosh/director/api/controllers/errands_controller'
require 'bosh/director/api/controllers/locks_controller'

module Bosh::Director
  module Api
    class Controller < Sinatra::Base
      use Controllers::BackupsController
      use Controllers::DeploymentsController
      use Controllers::InfoController
      use Controllers::PackagesController
      use Controllers::ReleasesController
      use Controllers::ResourcesController
      use Controllers::ResurrectionController
      use Controllers::StemcellsController
      use Controllers::TasksController
      use Controllers::UsersController
      use Controllers::CompiledPackagesController
      use Controllers::ErrandsController
      use Controllers::LocksController
    end
  end
end
