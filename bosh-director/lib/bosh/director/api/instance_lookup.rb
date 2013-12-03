require 'bosh/director/api/deployment_lookup'

module Bosh::Director
  module Api
    class InstanceLookup
      def by_id(instance_id)
        instance = Models::Instance[instance_id]
        if instance.nil?
          raise InstanceNotFound, "Instance #{instance_id} doesn't exist"
        end
        instance
      end

      def by_attributes(deployment_name, job_name, job_index)
        deployment = DeploymentLookup.new.by_name(deployment_name)

        # Postgres cannot coerce an empty string to integer, and fails on Models::Instance.find
        job_index = nil if job_index.is_a?(String) && job_index.empty?

        filter = {
          deployment_id: deployment.id,
          job: job_name,
          index: job_index
        }

        instance = Models::Instance.find(filter)
        if instance.nil?
          raise InstanceNotFound,
                "`#{deployment_name}/#{job_name}/#{job_index}' doesn't exist"
        end
        instance
      end

      def by_filter(filter)
        instances = Models::Instance.filter(filter).all
        if instances.empty?
          raise InstanceNotFound, "No instances matched #{filter.inspect}"
        end
        instances
      end

      def find_all
        Models::Instance.all
      end
    end
  end
end
