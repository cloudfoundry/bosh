# Copyright (c) 2012 VMware, Inc.

require "spec_helper"
require "common/exec"

describe Bosh::Exec do

  def self.test_adapter(adapter)
    let(:opts) { {:adapter => adapter} }

    describe adapter do
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
    end
  end

  test_adapter(:open4)
  test_adapter(:posix_spawn)

  describe "mock" do
    it "should be possible to mock 'sh'" do
      cmd = "ls /"
      result = Bosh::Exec::Result.new(cmd, "ouput", 0)
      Bosh::Exec.should_receive(:sh).with(cmd).and_return(result)
      result = Bosh::Exec.sh(cmd)
      result.success?.should be_true
    end
  end

end
