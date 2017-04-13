require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    module DnsSecurity
      def route(verb, path, options = {}, &block)
        options[:scope] ||= :authorization
        options[:authorization] ||= :admin
        super(verb, path, options, &block)
      end

      def authorization(perm)
        return unless perm

        condition do
          subject = :director

          if params.has_key?('deployment')
            @deployment = Bosh::Director::Api::DeploymentLookup.new.by_name(params[:deployment])
            subject = @deployment
          end

          @permission_authorizer.granted_or_raise(subject, perm, token_scopes)
        end
      end
    end

    class DnsController < BaseController
      register DnsSecurity

      def initialize(config)
        super(config)
        @deployment_manager = Api::DeploymentManager.new
        @instance_manager = Api::InstanceManager.new
      end

      get '/', authorization: :read do
        ['deployment', 'instance_group', 'instance', 'network'].each do |param_key|
          next unless params[param_key].nil?

          status 400
          body "missing parameter #{param_key}"
          return
        end

        deployment = Bosh::Director::Api::DeploymentLookup.new.by_name(params['deployment'])

        instance = @instance_manager.find_by_name(deployment, params['instance_group'], params['instance'])

        unless instance.spec['networks'].has_key?(params['network'])
          status 400
          body 'network not found'
          return
        end

        records = []

        records.push({
          'name' => DnsNameGenerator.dns_record_name(
            instance.uuid,
            instance.job,
            params['network'],
            deployment.name,
            Config.root_domain,
          )
        })

        headers 'Content-Type' => 'application/json'
        json_encode(records)
      end
    end
  end
end
