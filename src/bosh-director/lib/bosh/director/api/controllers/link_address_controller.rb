require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class LinkAddressController < BaseController
      register Bosh::Director::Api::Extensions::DeploymentsSecurity

      def initialize(config)
        super(config)
        @deployment_manager = Api::DeploymentManager.new
        @links_api_manager = Api::LinksApiManager.new
      end

      get '/', authorization: :read_link do
        validate_query_params(params)

        query_options = {
          azs: params['azs'],
          status: params['status'],
        }

        result = {
          address: @links_api_manager.link_address(params['link_id'], query_options),
        }

        body(json_encode(result))
      end

      private

      def validate_query_params(params)
        raise(LinkIdRequiredError, 'Link id is required') unless params.has_key?('link_id')
        validate_azs(params[:azs])
        validate_status(params[:status])
      end

      def validate_azs(azs)
        return if azs.nil?
        raise LinkInvalidAzsError, '`azs` param must be array type: `azs[]=`' unless azs.is_a?(Array)
        az_manager = Api::AvailabilityZoneManager.new
        azs.each do |az_name|
          raise(LinkInvalidAzsError, "az #{az_name} is not valid") unless az_manager.is_az_valid?(az_name)
        end
      end

      def validate_status(status)
        return if status.nil?
        valid_status = %w(healthy unhealthy all default)
        raise(LinkInvalidStatusError, "status must be a one of: #{valid_status}") unless status.is_a?(String) && valid_status.include?(status)
      end
    end
  end
end
