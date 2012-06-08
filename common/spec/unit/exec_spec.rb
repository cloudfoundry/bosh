# Copyright (c) 2012 VMware, Inc.

require "spec_helper"
require "common/exec"

describe Bosh::Exec do
  let(:opts) { {} }

  describe "existing command" do

    describe "executes successfully" do
      it "should not fail" do
        Bosh::Exec.sh("ls /", opts).failed?.should be_false
      end

      it "should execute block" do
        block = false
        Bosh::Exec.sh("ls /", opts) do
          block = true
        end
        block.should be_true
      end
    end

    describe "fails to execute" do
      it "should raise error by default" do
        lambda {
          Bosh::Exec.sh("ls /asdasd 2>&1", opts)
        }.should raise_error Bosh::Exec::Error
      end

      it "should yield block on false" do
        opts[:yield] = :on_false
        block = false
        Bosh::Exec.sh("ls /asdasd 2>&1", opts) do
          block = true
        end
        block.should be_true
      end

      it "should return result" do
        opts[:on_error] = :return
        Bosh::Exec.sh("ls /asdasd 2>&1", opts).failed?.should be_true
      end
    end

  end

  describe "missing command" do
    it "should raise error by default" do
      lambda {
        Bosh::Exec.sh("/asdasd 2>&1", opts)
      }.should raise_error Bosh::Exec::Error
    end

    it "should not raise error when requested" do
      opts[:on_error] = :return
      lambda {
        Bosh::Exec.sh("/asdasd 2>&1", opts)
      }.should_not raise_error Bosh::Exec::Error
    end

    it "should execute block when requested" do
      opts[:yield] = :on_false
      lambda {
      Bosh::Exec.sh("/asdasd 2>&1", opts) do
        raise "foo"
      end
      }.should raise_error "foo"
    end

  end

  describe "mock" do
    it "should be possible fake result" do
      cmd = "ls /"
      result = Bosh::Exec::Result.new(cmd, "output", 0)
      Bosh::Exec.should_receive(:sh).with(cmd).and_return(result)
      result = Bosh::Exec.sh(cmd)
      result.success?.should be_true
    end
  end

  describe "module" do
    it "should be possible to invoke as a module" do
      Bosh::Exec.sh("ls /").success?.should be_true
    end
  end

  describe "include" do
    class IncludeTest
      include Bosh::Exec
      def run
        sh("ls /")
      end

      def self.run
        sh("ls /")
      end
    end

    it "should add instance method" do
      inc = IncludeTest.new
      inc.run.success?.should be_true
    end

    it "should add class method" do
      IncludeTest.run.success?.should be_true
    end
  end
end
