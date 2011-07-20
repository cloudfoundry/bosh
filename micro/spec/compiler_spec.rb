require 'spec_helper'
require 'micro/compiler'

describe VCAP::Micro::Compiler do

  SPEC = File.expand_path("spec/assets/micro.yml")
  TGZ = File.expand_path("spec/assets/spec.tgz")
  FAIL = File.expand_path("spec/assets/fail.tgz")
  TMP = File.expand_path("tmp")
  CACHE = File.join(TMP, "data/cache")

  OPTS = {
    "base_dir" => TMP,
    "blobstore_options" => { "blobstore_path" => CACHE },
    "logging"   => { "level" => "WARN" },
  }

  before(:all) do
    FileUtils.rm_rf(TMP)
  end

  it "should compile packages" do
    c = VCAP::Micro::Compiler.new(OPTS)
    packages = c.compile(SPEC, TGZ)
    packages.should have_key("foo")
    packages.should have_key("bar")
    packages.should have_key("micro")

    # three packages and one job
    Dir.glob("#{CACHE}/[a-z0-9]*").size.should == 4

    File.exist?("#{TMP}/micro/apply_spec.yml").should be_true
  end

  it "should raise an exception if the tarball is missing" do
    c = VCAP::Micro::Compiler.new(OPTS)
    lambda {
      c.compile(SPEC, "bogus/path")
    }.should raise_exception RuntimeError
  end

  it "should raise an exception if the spec is missing" do
    c = VCAP::Micro::Compiler.new(OPTS)
    lambda {
      c.compile("bogus/path", TGZ)
    }.should raise_exception RuntimeError
  end

  it "should exit non zero on compile error" do
    c = VCAP::Micro::Compiler.new(OPTS)
    lambda {
      c.compile(SPEC, FAIL)
    }.should raise_exception SystemExit
  end
end
