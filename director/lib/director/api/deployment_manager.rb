# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class DeploymentManager
      include ApiHelper
      include TaskHelper

      def create_deployment(user, deployment_manifest, options = {})
        random_name = "deployment-#{UUIDTools::UUID.random_create}"
        deployment_manifest_file = File.join(Dir::tmpdir, random_name)

        write_file(deployment_manifest_file, deployment_manifest)
        task = create_task(user, :update_deployment, "create deployment")
        Resque.enqueue(Jobs::UpdateDeployment, task.id,
                       deployment_manifest_file, options)
        task
      end

      def delete_deployment(user, deployment, options = {})
        task = create_task(user, :delete_deployment,
                           "delete deployment: #{deployment.name}")
        Resque.enqueue(Jobs::DeleteDeployment, task.id,
                       deployment.name, options)
        task
      end

      def deployment_to_json(deployment)
        result = {
            "manifest" => deployment.manifest,
        }

        Yajl::Encoder.encode(result)
      end

      def deployment_vms_to_json(deployment)
        vms = []
        filters = {:deployment_id => deployment.id}
        Models::Vm.eager(:instance).filter(filters).all.each do |vm|
          instance = vm.instance

          vms << {
              "agent_id" => vm.agent_id,
              "cid" => vm.cid,
              "job" => instance ? instance.job : nil,
              "index" => instance ? instance.index : nil
          }
        end

        Yajl::Encoder.encode(vms)
      end
    end
  end
end
