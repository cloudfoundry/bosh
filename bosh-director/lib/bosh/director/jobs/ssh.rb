# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    class Ssh < BaseJob
      DEFAULT_SSH_DATA_LIFETIME = 300
      SSH_TAG = "ssh"
      @queue = :normal

      def self.job_type
        :ssh
      end

      def initialize(deployment_id, options = {})
        @deployment_id = deployment_id
        @target = options["target"]
        @command = options["command"]
        @params = options["params"]
        @blobstore = options.fetch(:blobstore) { App.instance.blobstores.blobstore }
        @instance_manager = Api::InstanceManager.new
      end

      def perform
        job = @target["job"]
        indexes = @target["indexes"]

        filter = {
          :deployment_id => @deployment_id
        }

        if indexes && indexes.size > 0
          filter[:index] = indexes
        end

        if job
          filter[:job] = job
        end

        instances = @instance_manager.filter_by(filter)

        ssh_info = instances.map do |instance|
          agent = @instance_manager.agent_client_for(instance)

          logger.info("ssh #{@command} `#{instance.job}/#{instance.index}'")
          result = agent.ssh(@command, @params)
          result["index"] = instance.index

          if Config.default_ssh_options
            result["gateway_host"] = Config.default_ssh_options["gateway_host"]
            result["gateway_user"] = Config.default_ssh_options["gateway_user"]
          end

          result
        end

        result_file.write(Yajl::Encoder.encode(ssh_info))
        result_file.write("\n")

        # task result
        nil
      end
    end
  end
end
