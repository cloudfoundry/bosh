require 'spec_helper'

module Bosh::Director::Api
  describe Controller do
    it 'includes each resourceful controller as middleware' do
      empty_args = []
      no_block = nil

      expect(Controller.middleware).to eq([
        [Controllers::BackupsController, empty_args, no_block],
        [Controllers::DeploymentsController, empty_args, no_block],
        [Controllers::InfoController, empty_args, no_block],
        [Controllers::PackagesController, empty_args, no_block],
        [Controllers::ReleasesController, empty_args, no_block],
        [Controllers::ResourcesController, empty_args, no_block],
        [Controllers::ResurrectionController, empty_args, no_block],
        [Controllers::StemcellsController, empty_args, no_block],
        [Controllers::TasksController, empty_args, no_block],
        [Controllers::UsersController, empty_args, no_block],
        [Controllers::CompiledPackagesController, empty_args, no_block],
        [Controllers::ErrandsController, empty_args, no_block],
        [Controllers::LocksController, empty_args, no_block],
      ])
    end
  end
end
