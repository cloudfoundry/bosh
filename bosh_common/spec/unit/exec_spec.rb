# Copyright (c) 2012 VMware, Inc.

require "spec_helper"
require "common/exec"

describe Bosh::Exec do
  let(:opts) { {} }

  context "existing command" do

    context "executes successfully" do
      it "should not fail" do
        Bosh::Exec.sh("ls /", opts).failed?.should be(false)
      end

      it "should execute block" do
        block = false
        Bosh::Exec.sh("ls /", opts) do
          block = true
        end
        block.should be(true)
      end
    end

    context "fails to execute" do
      it "should raise error by default" do
        expect {
          Bosh::Exec.sh("ls /asdasd 2>&1", opts)
        }.to raise_error { |error|
          error.should be_a Bosh::Exec::Error
          error.output.should match /No such file or directory/
        }
      end

      it "should yield block on false" do
        opts[:yield] = :on_false
        block = false
        Bosh::Exec.sh("ls /asdasd 2>&1", opts) do
          block = true
        end
        block.should be(true)
      end

      it "should return result" do
        opts[:on_error] = :return
        Bosh::Exec.sh("ls /asdasd 2>&1", opts).failed?.should be(true)
      end
    end

  end

  context "missing command" do
    it "should raise error by default" do
      expect {
        Bosh::Exec.sh("/asdasd 2>&1", opts)
      }.to raise_error Bosh::Exec::Error
    end

    it "should not raise error when requested" do
      opts[:on_error] = :return
      expect {
        Bosh::Exec.sh("/asdasd 2>&1", opts)
      }.to_not raise_error Bosh::Exec::Error
    end

    it "should execute block when requested" do
      opts[:yield] = :on_false
      expect {
      Bosh::Exec.sh("/asdasd 2>&1", opts) do
        raise "foo"
      end
      }.to raise_error "foo"
    end

  end

  context "mock" do
    it "should be possible fake result" do
      cmd = "ls /"
      result = Bosh::Exec::Result.new(cmd, "output", 0)
      Bosh::Exec.should_receive(:sh).with(cmd).and_return(result)
      result = Bosh::Exec.sh(cmd)
      result.success?.should be(true)
    end
  end

  context "module" do
    it "should be possible to invoke as a module" do
      Bosh::Exec.sh("ls /").success?.should be(true)
    end
  end

  context "include" do
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
      inc.run.success?.should be(true)
    end

    it "should add class method" do
      IncludeTest.run.success?.should be(true)
    end
  end
end
