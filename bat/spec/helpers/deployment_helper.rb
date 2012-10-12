# Copyright (c) 2012 VMware, Inc.

module DeploymentHelper

  # if with_deployment() is called without a block, it is up to the caller to
  # remove the generated deployment file
  def with_deployment(spec)
    context = Bosh::Common::TemplateEvaluationContext.new(spec)
    erb = ERB.new(load_template(context.spec.cpi))

    manifest_path = store_manifest(erb.result(context.get_binding))

    yield manifest_path if block_given?
    manifest_path
  ensure
    if block_given? && manifest_path
      puts "<-- removing manifest: #{manifest_path}" if debug?
      FileUtils.rm_f(manifest_path)
    end
  end

  def store_manifest(content)
    manifest = Tempfile.new("deployment-")
    puts "--> created manifest: #{manifest.path}" if debug?
    manifest.write(content)
    manifest.close
    manifest.path
  end

  def load_template(cpi)
    template = File.expand_path("../../../templates/#{cpi}.yml.erb", __FILE__)
    File.read(template)
  end

  def use_static_ip(spec)
    spec["properties"]["use_static_ip"] = true
  end

  def static_ip(spec)
    spec["properties"]["static_ip"]
  end

  def use_persistent_disk(spec, size)
    spec["properties"]["persistent_disk"] = size
  end

end
