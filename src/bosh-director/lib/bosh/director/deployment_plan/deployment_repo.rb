require 'securerandom'

module Bosh::Director
  module DeploymentPlan
    class DeploymentRepo

      def find_or_create_by_name(name, options={})
        attributes = {name: name}
        deployment = Bosh::Director::Models::Deployment.find(attributes)

        if deployment and deployment.name != name
          # mysql database is case-insensitive by default, so we might have a
          # deployment which doesn't exactly match the requested name
          deployment = nil
        end

        return deployment if deployment

        if options['scopes']
          team_scopes = Bosh::Director::Models::Team.transform_admin_team_scope_to_teams(options['scopes'])
          attributes.merge!(teams: team_scopes)
        end

        attributes.merge!(cloud_config: options['cloud_config'], runtime_configs: options['runtime_configs'])
        create_for_attributes(attributes)
      end

      private

      def create_for_attributes(attributes)
        canonical_name = Canonicalizer.canonicalize(attributes[:name])
        transactor = Transactor.new
        transactor.retryable_transaction(Models::Deployment.db) do
          Bosh::Director::Models::Deployment.each do |other|
            if Canonicalizer.canonicalize(other.name) == canonical_name
                raise DeploymentCanonicalNameTaken,
                "Invalid deployment name '#{attributes[:name]}', canonical name already taken ('#{canonical_name}')"
            end
          end

          Bosh::Director::Models::Deployment.create_with_teams(attributes)
        end
      end
    end
  end
end
