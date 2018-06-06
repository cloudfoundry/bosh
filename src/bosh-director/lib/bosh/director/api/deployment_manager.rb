module Bosh::Director
  module Api
    class DeploymentManager
      include ApiHelper

      def initialize
        @deployment_lookup = DeploymentLookup.new
      end

      def find_by_name(name)
        @deployment_lookup.by_name(name)
      end

      def all_by_name_asc
        all_by_name_eagerly_asc([:stemcells,
                                 release_versions: :release,
                                 teams: proc { |ds| ds.select(:id, :name) },
                                 cloud_configs: proc { |ds| ds.select(:id, :type) }])
      end

      def all_by_name_without_configs_asc
        all_by_name_eagerly_asc([:stemcells,
                                 release_versions: :release,
                                 teams: proc { |ds| ds.select(:id, :name) }])
      end

      def create_deployment(username, manifest_text, cloud_configs, runtime_configs, deployment, options = {}, context_id = '')
        cloud_config_ids = cloud_configs.map(&:id)
        runtime_config_ids = runtime_configs.map(&:id)

        description = 'create deployment'
        description += ' (dry run)' if options['dry_run']

        JobQueue.new.enqueue(username, Jobs::UpdateDeployment, description,
                             [manifest_text, cloud_config_ids, runtime_config_ids, options], deployment, context_id)
      end

      def delete_deployment(username, deployment, _options = {}, context_id = '')
        JobQueue.new.enqueue(username, Jobs::DeleteDeployment, "delete deployment #{deployment.name}",
                             %w[deployment.name options], deployment, context_id)
      end

      private

      def all_by_name_eagerly_asc(eager_list)
        Bosh::Director::Models::Deployment
          .eager(eager_list)
          .order_by(Sequel.asc(:name))
          .all
      end
    end
  end
end
