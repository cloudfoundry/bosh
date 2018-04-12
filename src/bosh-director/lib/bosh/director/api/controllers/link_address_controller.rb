require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class LinkAddressController < BaseController
      register DeploymentsSecurity

      def initialize(config)
        super(config)
        @deployment_manager = Api::DeploymentManager.new
        @link_manager = Api::LinkManager.new
      end

      get '/', authorization: :read do
        if params['link_id'].nil?
          raise LinkIdRequiredError, 'Link id is required'
        end

        query = {
          azs: [(params['az'] || [])].flatten
        }

        result = {
          address: @link_manager.link_address(params['link_id'], query)
        }

        body(json_encode(result))
      end
    end
  end
end
