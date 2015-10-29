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
        @target_payload = options["target"]
        @command = options["command"]
        @params = options["params"]
        @blobstore = options.fetch(:blobstore) { App.instance.blobstores.blobstore }
        @instance_manager = Api::InstanceManager.new
      end

      def perform
        target = Target.new(@target_payload)

        filter = {
          :deployment_id => @deployment_id
        }

        if target.id_provided?
          filter[:uuid] = target.id
        elsif target.indexes_provided?
          filter[:index] = target.indexes
        end

        filter[:job] = target.job if target.job

        instances = @instance_manager.filter_by(filter)

        ssh_info = instances.map do |instance|
          agent = @instance_manager.agent_client_for(instance)

          logger.info("ssh #{@command} `#{instance.job}/#{instance.uuid}'")
          result = agent.ssh(@command, @params)
          if target.id_provided?
            result["id"] = instance.uuid
          else
            result["index"] = instance.index
          end

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

      private

      class Target
        attr_reader :job, :indexes, :id

        def initialize(target_payload)
          @job = target_payload['job']
          @indexes = target_payload['indexes']
          @id = target_payload['id']
        end

        def id_provided?
          @id && !@id.empty?
        end

        def indexes_provided?
          @indexes && @indexes.size > 0
        end
      end
    end
  end
end
