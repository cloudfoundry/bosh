# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

require "common/exec"

describe Bosh::Exec do

  class IncludeTest
    include Bosh::Exec
    def instance_method(command)
      sh(command)
    end
  end

  class ExtendTest
    extend Bosh::Exec
    def self.class_method(command)
      sh(command)
    end
  end

  describe "existing command" do
    it "should succeed on zero return" do
      result = Bosh::Exec.sh("ls /")
      result.status.should == 0
      result.ok?.should be_true
      result.failed?.should be_false
      result.stdout.should_not be_empty
      result.stderr.should be_empty
    end

    it "should raise error on non-zero return when requested" do
      lambda {
        Bosh::Exec.sh("ls /asdasd", true)
      }.should raise_error Bosh::Exec::Error
    end
  end

  describe "missing command" do
    it "should fail to execute" do
      Bosh::Exec.sh("asdasd") do |result|
        result.failed?.should be_true
      end
    end
  end

  describe "include" do
    it "should work with instance method" do
      IncludeTest.new.instance_method("ls /")
    end
  end

  describe "extend" do
    it "should work with class method" do
      ExtendTest.class_method("ls /")
    end
  end

end
