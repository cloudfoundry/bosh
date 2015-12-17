module Bosh
  module Director
    module DeploymentPlan
      class DeploymentRepo
        def find_or_create_by_name(name)
          deployment = Models::Deployment.find(name: name)
          return deployment if deployment

          canonical_name = Canonicalizer.canonicalize(name)
          transactor = Transactor.new
          transactor.retryable_transaction(Models::Deployment.db) do
            Models::Deployment.each do |other|
              if Canonicalizer.canonicalize(other.name) == canonical_name
                raise DeploymentCanonicalNameTaken,
                  "Invalid deployment name `#{name}', canonical name already taken (`#{canonical_name}')"
              end
            end
            Models::Deployment.create(name: name)
          end
        end
      end
    end
  end
end
