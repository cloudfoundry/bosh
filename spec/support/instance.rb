module Bosh::Spec
  class Instance
    attr_reader :id, :job_name, :index, :is_bootstrap, :az, :disk_cid

    def initialize(id, job_name, index, is_bootstrap, az, disk_cid)
      @id = id
      @job_name = job_name
      @index = index
      @is_bootstrap = is_bootstrap
      @az = az
      @disk_cid = disk_cid
    end
  end
end
