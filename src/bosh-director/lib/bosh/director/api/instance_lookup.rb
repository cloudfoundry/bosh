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
      
      def by_job(deployment, job_name)
        instances = Models::Instance.filter(deployment: deployment, job: job_name)
        if instances.empty?
          raise InstanceNotFound, "No instances matched,#{deployment.name}/#{job_name}"
        end
        instances
      end
      
      def by_attributes(deployment, job_name, job_index)
        # Postgres cannot coerce an empty string to integer, and fails on Models::Instance.find
        job_index = nil if job_index.is_a?(String) && job_index.empty?

        instance = Models::Instance.find(deployment: deployment, job: job_name, index: job_index)
        if instance.nil?
          raise InstanceNotFound,
            "'#{deployment.name}/#{job_name}/#{job_index}' doesn't exist"
        end
        instance
      end

      def by_uuid(deployment, job_name, uuid)
        instance = Models::Instance.find(deployment: deployment, job: job_name, uuid: uuid)
        if instance.nil?
          raise InstanceNotFound,
            "'#{deployment.name}/#{job_name}/#{uuid}' doesn't exist"
        end
        instance
      end

      def by_filter(filter)
        instances = Models::Instance.filter(filter)
        if instances.empty?
          raise InstanceNotFound, "No instances matched #{filter.inspect}"
        end
        instances
      end

      def find_all
        Models::Instance.all
      end

      def by_deployment(deployment)
        Models::Instance.filter(deployment: deployment).all
      end

      def by_vm_cid(vm_cid)
        vm = Models::Vm.filter(cid: vm_cid, active: true).first
        if vm.nil?
          raise InstanceNotFound, "No instances matched vm cid '#{vm_cid}'"
        end
        [vm.instance]
      end
    end
  end
end
