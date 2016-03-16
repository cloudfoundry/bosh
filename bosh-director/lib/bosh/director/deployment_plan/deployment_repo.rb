module Bosh::Director
  module DeploymentPlan
    class DeploymentRepo

      def find_or_create_by_name(name, options={})
        attributes = {name: name}
        deployment = Bosh::Director::Models::Deployment.find(attributes)

        return deployment if deployment

        if options['scopes']
          team_scopes = Bosh::Director::Models::Deployment.transform_admin_team_scope_to_teams(options['scopes'])
          attributes.merge!(teams: team_scopes.join(','))
        end

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
          Bosh::Director::Models::Deployment.create(attributes)
        end
      end
    end
  end
end
