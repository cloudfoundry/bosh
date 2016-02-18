module Bosh::Director
  module DeploymentPlan
    class DeploymentRepo
      def initialize
        @permission_authorizer = Bosh::Director::PermissionAuthorizer.new
      end

      def find_or_create_by_name(name, options={})
        attributes = {name: name}
        deployment = Bosh::Director::Models::Deployment.find(attributes)

        if options['scopes']
          attributes.merge!(scopes: options['scopes'].join(','))
        end

        if options['scopes'] && deployment
          @permission_authorizer.raise_error_if_unauthorized(options['scopes'], deployment.scopes.split(','))
        end

        return deployment if deployment

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
                "Invalid deployment name `#{attributes[:name]}', canonical name already taken (`#{canonical_name}')"
            end
          end
          Bosh::Director::Models::Deployment.create(attributes)
        end
      end
    end
  end
end
