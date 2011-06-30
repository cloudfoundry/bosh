require 'spec_helper'
require 'micro/compiler'

describe VCAP::Micro::Compiler do
  it "should compile micro cloud" do
    tarball = "spec/assets/micro.tgz"
    manifest = "spec/assets/micro.yml"
    opts = {
      "logging" => {"level" => "DEBUG"},
      "base_dir"  => File.expand_path("tmp")
    }
    c = VCAP::Micro::Compiler.new(manifest, tarball, opts)
    lambda { c.run }.should_not raise_error
  end
end