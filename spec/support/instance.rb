module Bosh::Spec
  class Instance
    attr_reader :id, :job_name, :index, :is_bootstrap, :az

    def initialize(id, job_name, index, is_bootstrap, az)
      @id = id
      @job_name = job_name
      @index = index
      @is_bootstrap = is_bootstrap
      @az = az
    end
  end
end
