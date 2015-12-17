module Bosh::Director
  module DeploymentPlan
    class LinkPath < Struct.new(:deployment, :job, :template, :name, :path)
      def self.parse(current_deployment_name, path, logger)
        parts = path.split('.')

        if parts.size == 3
          logger.debug("Link '#{path}' does not specify deployment, using current deployment")
          parts.unshift(current_deployment_name)
        end

        if parts.size != 4
          logger.error("Invalid link format: #{path}")
          raise DeploymentInvalidLink,
            "Link '#{path}' is invalid. A link must have either 3 or 4 parts: " +
              "[deployment_name.]job_name.template_name.link_name"
        end

        new(*parts, path)
      end

      def to_s
        path
      end
    end
  end
end
