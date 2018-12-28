require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class CloudConfigsController < BaseController
      post '/', :consumes => :yaml do
        manifest_text = request.body.read
        begin
          validate_manifest_yml(manifest_text, nil)

          latest_cloud_config = Bosh::Director::Api::CloudConfigManager.new.list(1)

          if latest_cloud_config.empty? || latest_cloud_config.first[:content] != manifest_text
            Bosh::Director::Api::CloudConfigManager.new.update(manifest_text)
            create_event
          end

        rescue => e
          create_event e
          raise e
        end
        status(201)
      end

      post '/diff', :consumes => :yaml do
        old_config_hash = cloud_config_or_empty(
          Bosh::Director::Models::Config.
            latest_set('cloud').
            find{|config| config[:name] == 'default'}
        )
        new_config_hash = validate_manifest_yml(request.body.read, nil) || {}

        result = {}
        changeset = {}
        begin
          changeset = Changeset.new(old_config_hash, new_config_hash)
          diff = changeset.diff(false).order
          result['diff'] = diff.map { |l| [l.to_s, l.status] }
        rescue => error
          result['diff'] = []
          result['error'] = "Unable to diff cloud-config: #{error.inspect}\n#{error.backtrace.join("\n")}"
        end

        unless valid_changeset?(changeset)
          status(400)
          result['diff'] = []
          result['error'] = 'Either all or no AZ must declare CPI'
        end

        json_encode(result)
      end

      get '/', scope: :read do
        if params['limit'].nil? || params['limit'].empty?
          status(400)
          body('limit is required')
          return
        end

        begin
          limit = Integer(params['limit'])
        rescue ArgumentError
          status(400)
          body("limit is invalid: '#{params['limit']}' is not an integer")
          return
        end

        cloud_configs = Bosh::Director::Api::CloudConfigManager.new.list(limit)
        json_encode(
          cloud_configs.map do |cloud_config|
            {
              "properties" => cloud_config.content,
              "created_at" => cloud_config.created_at,
            }
          end
        )
      end

      private

      def cloud_config_or_empty(cloud_config_model)
        return {} if cloud_config_model.nil? || cloud_config_model.raw_manifest.nil?
        cloud_config_model.raw_manifest
      end

      def create_event(error = nil)
        @event_manager.create_event({
            user:        current_user,
            action:      'update',
            object_type: 'cloud-config',
            object_name: 'default',
            error:       error
        })
      end

      def valid_changeset?(changeset)
        return true if changeset.merged.nil? || changeset.merged['azs'].nil?

        azs = changeset.merged['azs']
        number_of_non_empty_cpis = azs.select { |az| az['cpi'] && !az['cpi'].empty? }.size

        number_of_non_empty_cpis == azs.size || number_of_non_empty_cpis.zero?
      end
    end
  end
end
