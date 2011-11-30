module Bosh::Director
  module Jobs
    class Ssh < BaseJob
      DEFAULT_SSH_DATA_LIFETIME = 300
      SSH_TAG = "ssh"
      @queue = :normal

      def initialize(deployment_id, options)
        super
        @deployment_id = deployment_id
        @target = options["target"]
        @command = options["command"]
        @params = options["params"]
        @blobstore = Config.blobstore
      end

      def perform
        job = @target["job"]
        indexes = @target["indexes"]
        instances = nil
        if job.nil?
          if indexes && indexes.size > 0
            instances = Models::Instance.filter(:deployment_id => @deployment_id, :index => indexes)
          else
            instances = Models::Instance.filter(:deployment_id => @deployment_id)
          end
        else
          if indexes && indexes.size > 0
            instances = Models::Instance.filter(:deployment_id => @deployment_id, :job => job, :index => indexes)
          else
            instances = Models::Instance.filter(:deployment_id => @deployment_id, :job => job, )
          end
        end
        raise InstanceNotFound.new("job: #{job}, index: #{index}") if instances.nil?

        ssh_info = []
        instances.each do |instance|
          vm = Models::Vm[instance.vm_id]
          agent = AgentClient.new(vm.agent_id)
          @logger.info("ssh #{@command} job: #{instance.job}, index: #{instance.index}")
          result = agent.ssh(@command, Yajl::Encoder.encode(@params))
          result["index"] = instance.index
          ssh_info << result
        end

        # Cleanup old blob store entries
        TransitDataManager.cleanup(SSH_TAG, DEFAULT_SSH_DATA_LIFETIME)

        blobstore_id = nil
        if @command == "setup"
          blobstore_id = @blobstore.create(Yajl::Encoder.encode(ssh_info))
          if blobstore_id.nil?
            raise "agent didn't return a blobstore object id for ssh info"
          end
          TransitDataManager.add(SSH_TAG, blobstore_id)
        end
        blobstore_id
      end
    end
  end
end
