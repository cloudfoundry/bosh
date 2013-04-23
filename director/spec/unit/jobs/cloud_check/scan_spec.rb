# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::Director::Jobs::CloudCheck::Scan do

  before do
    BDM::Deployment.make(name: 'deployment')
    Bosh::Director::ProblemScanner.stub(new: scanner)
  end

  let(:job) { described_class.new('deployment') }
  let(:scanner) { double(Bosh::Director::ProblemScanner)}
  let(:deployment) { BDM::Deployment[1] }

  it 'should obtain a deployment lock' do
    job.should_receive(:with_deployment_lock).and_yield

    scanner.as_null_object

    job.perform
  end

  it 'should run the scan' do
    job.stub(:with_deployment_lock).and_yield

    scanner.should_receive(:reset).ordered
    scanner.should_receive(:scan_vms).ordered
    scanner.should_receive(:scan_disks).ordered

    job.perform
  end
end
