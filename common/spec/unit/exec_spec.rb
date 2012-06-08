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
          it "should fail" do
            Bosh::Exec.sh("ls /asdasd", opts).failed?.should be_true
          end

          it "should not execute block" do
            block = false
            Bosh::Exec.sh("ls /asdasd", opts) do
              block = true
            end
            block.should be_false
          end

          it "should raise error" do
            lambda {
              Bosh::Exec.sh("ls /asdasd", :on_error => :raise)
            }.should raise_error Bosh::Exec::Error
          end
        end

      end

      describe "missing command" do
        it "should not raise error" do
          lambda {
            Bosh::Exec.sh("/asdasd", opts)
          }.should_not raise_error Bosh::Exec::Error
        end

        it "should raise error when requested" do
          opts[:on_error] = :raise
          lambda {
            Bosh::Exec.sh("/asdasd", opts)
          }.should raise_error Bosh::Exec::Error
        end

        it "should not execute block" do
          block = false
          lambda {
          Bosh::Exec.sh("/asdasd", opts) do
            block = true
          end
          }
          block.should be_false
        end

        it "should execute block when requested" do
          opts[:block] = :on_false
          opts[:on_error] = :return
          lambda {
          Bosh::Exec.sh("/asdasd", opts) do
            raise "foo"
          end
          }.should raise_error "foo"
        end

      end
    end

  end

  test_adapter(:open4)
  test_adapter(:posix_spawn)

end
