# Copyright (c) 2012 VMware, Inc.

module DeploymentHelper

  def stemcell
    @stemcell ||= Stemcell.from_path(read_environment('BAT_STEMCELL'))
  end

  def release
    @release ||= Release.from_path(read_environment('BAT_RELEASE_DIR'))
  end

  # @return [Array[String]]
  def deployments
    result = {}
    jbosh("/deployments").each {|d| result[d["name"]] = d}
    result
  end

  # @return [Array[Release]]
  def releases
    result = []
    jbosh("/releases").each do |r|
      result << Release.new(r["name"], r["versions"])
    end
    result
  end

  # @return [Array[Stemcell]]
  def stemcells
    result = []
    jbosh("/stemcells").each do |s|
      result << Stemcell.new(s["name"], s["version"])
    end
    result
  end

  # @return [Array[VM]]
  def vms(deployment, polls=30)
    vm_path = "/deployments/#{deployment}/vms?format=full"
    task_uri = http_client.get([director_url, vm_path].join).headers["Location"]
    task_uri.should =~ /\/tasks\/(\d+)\/?$/ # Looks like we received task URI
    task_result_uri = [task_uri, "/output?type=result"].join

    body = nil
    tries = polls.times do
      body = http_client.get(task_result_uri, "application/json").body
      break unless body.empty?
      sleep(1)
    end

    if tries == polls && body.empty?
      raise "failed to get VMs after #{tries} tries from `#{task_result_uri}'"
    end

    body.to_s.split("\n").map do |vm_state|
      VM.new(JSON.parse(vm_state))
    end
  end

  def requirement(what, present=true)
    case what
    when Stemcell
      if stemcells.include?(stemcell)
        puts "stemcell already uploaded" if debug?
      else
        puts "stemcell not uploaded" if debug?
        bosh("upload stemcell #{what.to_path}")
      end
    when Release
      if releases.include?(release)
        puts "release already uploaded" if debug?
      else
        puts "release not uploaded" if debug?
        bosh("upload release #{what.to_path}")
      end
    when :no_tasks_processing
      if tasks_processing?
        raise "director `#{bosh_director}' is currently processing tasks"
      end
    else
      raise "unknown requirement: #{what}"
    end
  end

  def cleanup(what)
    # if BAT_FAST is set, we just return so the stemcell & release is
    # preserved - this saves a lot of time!
    return if fast?
    case what
    when Stemcell
      bosh("delete stemcell #{what.name} #{what.version}")
    when Release
      bosh("delete release #{what.name}")
    else
      raise "unknown cleanup: #{what}"
    end
  end

  def load_deployment_spec
    @spec ||= YAML.load_file(read_environment('BAT_DEPLOYMENT_SPEC'))
    # Always set the batlight.missing to something, or deployments will fail.
    # It is used for negative testing.
    @spec["properties"]["batlight"] ||= {}
    @spec["properties"]["batlight"]["missing"] = "nope"
  end

  # if with_deployment() is called without a block, it is up to the caller to
  # remove the generated deployment file
  # @return [Deployment]
  def with_deployment(spec={}, &block)
    deployed = false # move into Deployment ?
    deployment = Deployment.new(@spec.merge(spec))

    if !block_given?
      return deployment
    elsif block.arity == 0
      bosh("deployment #{deployment.to_path}").should succeed
      bosh("deploy").should succeed
      deployed = true
      yield
    elsif block.arity == 1
      yield deployment
    elsif block.arity == 2
      bosh("deployment #{deployment.to_path}").should succeed
      result = bosh("deploy")
      result.should succeed
      deployed = true
      yield deployment, result
    else
      raise "unknown arity: #{block.arity}"
    end
  ensure
    if block_given?
      deployment.delete if deployment
      if deployed
        bosh("delete deployment #{deployment.name}").should succeed
      end
    end
  end

  def use_job(job)
    @spec["properties"]["job"] = job
  end

  def use_template(template)
    @spec["properties"]["template"] = if template.respond_to?(:each)
      string = ""
      template.each do |item|
        string += "\n      - #{item}"
      end
      string
    else
      template
    end
  end

  def use_job_instances(count)
    @spec["properties"]["jobs"] = count
  end

  def use_deployment_name(name)
    @spec["properties"]["name"] = name
  end

  def use_release(version)
    @spec["properties"]["release"] = version
  end

  def use_static_ip
    @spec["properties"]["use_static_ip"] = true
  end

  def static_ip
    @spec["properties"]["static_ip"]
  end

  def use_persistent_disk(size)
    @spec["properties"]["persistent_disk"] = size
  end

  def use_canaries(count)
    @spec["properties"]["canaries"] = count
  end

  def use_max_in_flight(count)
    @spec["properties"]["max_in_flight"] = count
  end

  def use_pool_size(size)
    @spec["properties"]["pool_size"] = size
  end

  def use_password(passwd)
    @spec["properties"]["password"] = passwd
  end

  def use_failing_job(where="control")
    @spec["properties"]["batlight"]["fail"] = where
  end

  def use_missing_property(property="missing")
    @spec["properties"]["batlight"].delete(property)
  end

  def get_task_id(output, state="done")
    match = output.match(/Task (\d+) #{state}/)
    match.should_not be_nil
    match[1]
  end

  def events(task_id)
    result = bosh("task #{task_id} --raw")
    result.should succeed_with /Task \d+ \w+/

    event_list = []
    result.output.split("\n").each do |line|
      event = parse(line)
      event_list << event if event
    end
    event_list
  end

  def start_and_finish_times_for_job_updates(task_id)
    jobs = {}
    events(task_id).select { |e|
      e["stage"] == "Updating job" && %w(started finished).include?(e["state"])
    }.each do |e|
      jobs[e["task"]] ||= {}
      jobs[e["task"]][e["state"]] = e["time"]
    end
    jobs
  end

  private

  def parse(line)
    JSON.parse(line)
  rescue JSON::ParserError
    # do nothing
  end

end
