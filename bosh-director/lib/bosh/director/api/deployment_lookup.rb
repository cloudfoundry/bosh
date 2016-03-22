module Bosh::Director
  module Api
    class DeploymentLookup
      def by_name(name)
        deployment = Models::Deployment[name: name]
        if deployment.nil?
          raise DeploymentNotFound, "Deployment '#{name}' doesn't exist"
        end
        deployment
      end
    end
  end
end
