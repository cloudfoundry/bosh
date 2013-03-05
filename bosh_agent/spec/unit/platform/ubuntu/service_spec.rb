# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + "/../../../spec_helper"

describe Bosh::Agent::Platform::Ubuntu::Service do

  let(:service) { Bosh::Agent::Platform::Ubuntu::Service.new("ssh") }

  it "should be able start service" do
    Bosh::Exec.should_receive(:sh).with("service ssh start")

    service.start
  end

  it "should be able stop service" do
    Bosh::Exec.should_receive(:sh).with("service ssh stop")

    service.stop
  end

  it "should be able check service status" do
    Bosh::Exec.should_receive(:sh).with("service ssh status")

    service.status
  end

  context "" do
    Result = Struct.new(:output) do
      attr_reader :output

      def initialize(output)
        @output = output
      end
    end

    before do
      Kernel.should_receive(:sleep).exactly(3).times.with(1)
    end

    it "should be able to start and wait a service" do
      Bosh::Exec.should_receive(:sh).with("service ssh start")
      Bosh::Exec.should_receive(:sh).exactly(3).times.with("service ssh status")\
        .and_return(Result.new("ssh stop/waiting"))

      lambda {
        service.start_and_wait(3)
      }.should raise_error(RuntimeError, /^Timeout to start service/)
    end

    it "should be able to start and wait a service" do
      Bosh::Exec.should_receive(:sh).with("service ssh stop")
      Bosh::Exec.should_receive(:sh).exactly(3).times.with("service ssh status")\
        .and_return(Result.new("ssh start/running, process 767"))

      lambda {
        service.stop_and_wait(3)
      }.should raise_error(RuntimeError, /^Timeout to stop service/)
    end
  end

end
