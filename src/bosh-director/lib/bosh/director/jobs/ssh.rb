module Bosh::Director
  module Jobs
    class Ssh < BaseJob
      DEFAULT_SSH_DATA_LIFETIME = 300
      SSH_TAG = "ssh"

      @queue = :urgent

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

        filter = {}
        filter[:job] = target.job if target.job
        filter.merge!(target.id_filter)

        deployment = Models::Deployment[@deployment_id]

        instances = @instance_manager.filter_by(deployment, filter).reject { |i| i.active_vm.nil? }

        if instances.empty?
          raise "No instance with a VM in deployment '#{deployment.name}' matched filter #{filter}"
        end

        ssh_info = instances.map do |instance|
          begin
            agent = @instance_manager.agent_client_for(instance)

            logger.info("ssh #{@command} '#{instance.job}/#{instance.uuid}'")
            result = agent.ssh(@command, @params)
            result["id"] = instance.uuid
            result["index"] = instance.index
            result["job"] = instance.job

            if Config.default_ssh_options
              result["gateway_host"] = Config.default_ssh_options["gateway_host"]
              result["gateway_user"] = Config.default_ssh_options["gateway_user"]
            end

            result
          rescue Exception => e
            raise e
          ensure
            add_event(deployment.name, instance.name, e)
          end
        end

        task_result.write(JSON.generate(ssh_info))
        task_result.write("\n")

        # task result
        nil
      end

      private

      def add_event(deployment_name, instance_name, error = nil)
        user =  @params['user_regex'] || @params['user']
        event_manager.create_event(
            {
                user:        username,
                action:      "#{@command} ssh",
                object_type: 'instance',
                object_name: instance_name,
                task:        task_id,
                error:       error,
                deployment:  deployment_name,
                instance:    instance_name,
                context:     {user: user}
            })
      end

      class Target
        attr_reader :job, :indexes, :ids

        def initialize(target_payload)
          @job = target_payload['job']
          @ids = target_payload['ids']
          @indexes = target_payload['indexes']
        end

        def ids_provided?
          @ids && @ids.size > 0
        end

        def indexes_provided?
          @indexes && @indexes.size > 0
        end

        def id_filter
          if !ids_provided? && indexes_provided?
            # for backwards compatibility with old cli
            return {index: @indexes}
          end

          filter = Hash.new { |h,k| h[k] = [] }

          @ids.each do |id|
            if id.to_s =~ /^\d+$/
              filter[:index] << id.to_i
            else
              filter[:uuid] << id
            end
          end

          filter
        end
      end
    end
  end
end
