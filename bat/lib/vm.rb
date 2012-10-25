class VM < Struct.new(:agent_id, :job_name, :job_state,
                      :index, :ips, :resource_pool, :vm_cid)

  def initialize(hash)
    super(*hash.values_at("agent_id", "job_name", "job_state",
                          "index", "ips", "resource_pool", "vm_cid"))
  end

  def name
    [self.job_name, self.index].join("/")
  end
end