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
    else
      raise "unknown arity: #{block.arity}"
    end
  ensure
    if block_given?
      deployment.delete if deployment
      if block.arity == 0 && deployed
        bosh("delete deployment #{deployment.name}").should succeed
      end
    end
  end

  def use_job(job)
    @spec["properties"]["job"] = job
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

  def get_task_id(output)
    match = output.match(/Task (\d+) done/)
    match.should_not be_nil
    match[1]
  end

  def events(task_id)
    result = bosh("task #{task_id} --raw")
    result.should succeed_with /Task \d+ done/

    event_list = []
    result.output.split("\n").each do |line|
      event = parse(line)
      event_list << event if event
    end
    event_list
  end

  private

  def parse(line)
    JSON.parse(line)
  rescue JSON::ParserError
    # do nothing
  end

end
