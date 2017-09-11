require 'bosh/director/api/deployment_lookup'
require 'bosh/director/ip_util'

module Bosh::Director
  module Api
    class InstanceLookup
      include Bosh::Director::IpUtil
      def by_id(instance_id)
        instance = Models::Instance[instance_id]
        if instance.nil?
          raise InstanceNotFound, "Instance #{instance_id} doesn't exist"
        end
        instance
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

      def by_filter(filter, deployment_name = "")
        instances = Models::Instance.filter(filter).all
        if instances.empty?
          if !filter[:job].nil? && ip_address?(filter[:job])
            instances = [by_ip(filter[:job], filter[:deployment_id], deployment_name)]
          else
            raise InstanceNotFound, "No instances matched #{filter.inspect}"
          end
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

      private

      def by_ip(ip_address, deployment_id, deployment_name)
        net_address = ip_to_netaddr(ip_address)
        ipaddress_model = Models::IpAddress.where(address: net_address.to_i).first
        if ipaddress_model.nil?
          instance = Models::Instance.filter([{ deployment_id: deployment_id }, Sequel.like(:spec_json, "%\\\"ip\\\":\\\"#{ip_address}\\\"%")]).first
          raise InstanceNotFound if instance.nil?
        else
          instance = by_id(ipaddress_model.instance_id)
        end
        instance
      rescue InstanceNotFound
        raise InstanceNotFound,
          "No instances in deployment '#{deployment_name}' matched ip address #{ip_address}"
      end
    end
  end
end
