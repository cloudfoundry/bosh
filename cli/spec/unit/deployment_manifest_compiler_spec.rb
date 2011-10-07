require 'spec_helper'

describe Bosh::Cli::DeploymentManifestCompiler do

  def make_compiler(manifest, deployment_properties = {}, release_properties = {})
    compiler = Bosh::Cli::DeploymentManifestCompiler.new(manifest)
    compiler.deployment_properties = deployment_properties
    compiler.release_properties = release_properties
    compiler
  end

  it "substitutes properties in a raw manifest" do
    raw_manifest = <<-MANIFEST.gsub(/^\s*/, "")
      ---
      name: mycloud
      release:
        name: test
        version: <%= release_property("live.version") %>
      properties:
        dea:
          max_memory: <%= deployment_property("dea.max_memory") %>
    MANIFEST

    compiler = make_compiler(raw_manifest, { "dea.max_memory" => 8192 }, { "live.version" => 32 })

    compiler.result.should == <<-MANIFEST.gsub(/^\s*/, "")
      ---
      name: mycloud
      release:
        name: test
        version: 32
      properties:
        dea:
          max_memory: 8192
    MANIFEST
  end

  it "whines on missing deployment properties" do
    raw_manifest = <<-MANIFEST.gsub(/^\s*/, "")
      ---
      name: mycloud
      properties:
        dea:
          max_memory: <%= deployment_property("missing.property") %>
    MANIFEST

    compiler = make_compiler(raw_manifest, { "dea.max_memory" => 8192 })
    error_msg = "Cannot resolve deployment property `missing.property'"

    lambda {
      compiler.result
    }.should raise_error(Bosh::Cli::DeploymentManifestCompiler::UndefinedProperty, error_msg)
  end

  it "whines on missing release properties" do
    raw_manifest = <<-MANIFEST.gsub(/^\s*/, "")
      ---
      name: mycloud
      release:
        name: test
        version: <%= release_property("test.property") %>
    MANIFEST

    compiler = make_compiler(raw_manifest)
    error_msg = "Cannot resolve release property `test.property'"

    lambda {
      compiler.result
    }.should raise_error(Bosh::Cli::DeploymentManifestCompiler::UndefinedProperty, error_msg)
  end

end
