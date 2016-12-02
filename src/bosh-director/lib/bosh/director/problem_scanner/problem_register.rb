module Bosh::Director::ProblemScanner
  class ProblemRegister
    def initialize(deployment, logger)
      @deployment = deployment
      @logger = logger

      @problem_lock = Mutex.new
    end

    def problem_found(type, resource, data = {})
      @problem_lock.synchronize do
        similar_open_problems = Bosh::Director::Models::DeploymentProblem.
          filter(deployment_id: @deployment.id, type: type.to_s,
          resource_id: resource.id, state: 'open').all

        if similar_open_problems.size > 1
          raise Bosh::Director::CloudcheckTooManySimilarProblems,
            "More than one problem of type '#{type}' " +
              "exists for resource #{type} #{resource.id}"
        end

        if similar_open_problems.empty?
          problem = Bosh::Director::Models::DeploymentProblem.
            create(type: type.to_s, resource_id: resource.id,
            state: 'open', deployment_id: @deployment.id,
            data: data, counter: 1)

          @logger.info("Created problem #{problem.id} (#{problem.type})")
        else
          # This assumes we are running with deployment lock acquired,
          # so there is no possible update conflict
          problem = similar_open_problems[0]
          problem.data = data
          problem.last_seen_at = Time.now
          problem.counter += 1
          problem.save
          @logger.info("Updated problem #{problem.id} (#{problem.type}), " +
            "count is now #{problem.counter}")
        end
      end
    end

    def get_disk(instance)
      mounted_disk_cid = nil

      @problem_lock.synchronize do
        mounted_disk_cid = instance.managed_persistent_disk_cid if instance
      end

      mounted_disk_cid
    end
  end
end
