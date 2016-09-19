module Bosh::Spec
  class Instance
    attr_reader :id, :job_name, :index, :bootstrap, :az, :disk_cids, :vm_cid

    def initialize(id, job_name, index, bootstrap, az, disk_cids, vm_cid)
      @id = id
      @job_name = job_name
      @index = index
      @bootstrap = bootstrap
      @az = az
      @disk_cids = disk_cids
      @vm_cid = vm_cid
    end
  end
end
