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

        query_options = {
          azs: [(params['az'] || [])].flatten,
          status: params['status']
        }

        validate_query_options(query_options)

        result = {
          address: @link_manager.link_address(params['link_id'], query_options)
        }

        body(json_encode(result))
      end

      private

      def validate_query_options(query_options)
        validate_azs(query_options[:azs])
        validate_status(query_options[:status])
      end

      def validate_azs(az_names)
        az_manager = Api::AvailabilityZoneManager.new
        az_names.each do |az_name|
          raise(LinkInvalidAzError, "az #{az_name} is not valid") unless az_manager.is_az_valid?(az_name)
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
