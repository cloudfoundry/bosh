# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe Jobs::CloudCheck::Scan do
    describe 'Resque job class expectations' do
      let(:job_type) { :cck_scan }
      it_behaves_like 'a Resque job'
    end

    describe 'instance methods' do
      before do
        deployment = Models::Deployment.make(name: 'deployment')
        ProblemScanner.should_receive(:new).with(deployment).and_return(scanner)
      end

      let(:job) { described_class.new('deployment') }
      let(:scanner) { instance_double('Bosh::Director::ProblemScanner') }
      let(:deployment) { Models::Deployment[1] }

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
  end
end
