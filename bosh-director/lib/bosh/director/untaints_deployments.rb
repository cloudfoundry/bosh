module Bosh::Director
  class UntaintsDeployments
    def initialize(deployment_manager, user)
      @deployment_manager = deployment_manager
      @user = user
    end

    def untaint_deployment!(deployment_name)
      deployment = deployment_manager.find_by_name(deployment_name)
      manifest = StringIO.new(deployment.manifest)
      deployment_manager.create_deployment(user, manifest, options(deployment))
    end

    private
    attr_reader :deployment_manager, :user

    def options(deployment)
      {
        'job_states' => job_states(deployment)
      }
    end

    def job_states(deployment)
      hash = {}

      deployment.tainted_instances.each do |instance|
        hash[instance.job] = { 'instance_states' => {} }
      end

      deployment.tainted_instances.each do |instance|
        hash[instance.job]['instance_states'].merge!(instance.index => 'recreate')
      end

      hash
    end
  end
end

