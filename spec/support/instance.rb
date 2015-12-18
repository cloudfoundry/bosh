module Bosh::Spec
  class Instance
    attr_reader :id, :job_name, :index, :bootstrap, :az, :disk_cid

    def initialize(id, job_name, index, bootstrap, az, disk_cid)
      @id = id
      @job_name = job_name
      @index = index
      @bootstrap = bootstrap
      @az = az
      @disk_cid = disk_cid
    end
  end
end
