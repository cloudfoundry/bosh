# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::DeploymentManifestCompiler do

  def make_compiler(manifest, properties = {})
    compiler = Bosh::Cli::DeploymentManifestCompiler.new(manifest)
    compiler.properties = properties
    compiler
  end

  it "substitutes properties in a raw manifest" do
    raw_manifest = <<-MANIFEST.gsub(/^\s*/, "")
      ---
      name: mycloud
      properties:
        dea:
          max_memory: <%= property("dea.max_memory") %>
    MANIFEST

    compiler = make_compiler(raw_manifest, { "dea.max_memory" => 8192 })

    expect(compiler.result).to eq <<-MANIFEST.gsub(/^\s*/, "")
      ---
      name: mycloud
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
          max_memory: <%= property("missing.property") %>
    MANIFEST

    compiler = make_compiler(raw_manifest, { "dea.max_memory" => 8192 })
    error_msg = "Cannot resolve deployment property 'missing.property'"

    expect {
      compiler.result
    }.to raise_error(Bosh::Cli::UndefinedProperty, error_msg)
  end

  it "whines if manifest has syntax error (from ERB's point of view)" do
    raw_manifest = <<-MANIFEST.gsub(/^\s*/, "")
      properties: <%=
        dea:
          max_memory: <%= property("missing.property") %>
    MANIFEST

    compiler = make_compiler(raw_manifest, { "dea.max_memory" => 8192 })

    expect {
      compiler.result
    }.to raise_error(Bosh::Cli::MalformedManifest)
  end
end
