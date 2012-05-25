# Copyright (c) 2009-2012 VMware, Inc.

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

        conditions = {:deployment_id => @deployment_id}
        conditions[:index] = indexes if indexes && indexes.size > 0
        conditions[:job] = job if job
        instances = Models::Instance.filter(conditions)
        raise InstanceNotFound.new("job: #{job}, index: #{index}") if instances.nil?

        ssh_info = []
        instances.each do |instance|
          vm = Models::Vm[instance.vm_id]
          agent = AgentClient.new(vm.agent_id)
          @logger.info("ssh #{@command} job: #{instance.job}, index: #{instance.index}")
          result = agent.ssh(@command, @params)
          result["index"] = instance.index
          ssh_info << result
        end
        @result_file.write(Yajl::Encoder.encode(ssh_info))
        @result_file.write("\n")

        # task result
        nil
      end
    end
  end
end
