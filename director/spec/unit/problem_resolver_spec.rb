# -*- encoding: utf-8 -*-
# Copyright (c) 2013 GoPivotal, Inc.

require 'spec_helper'

describe Bosh::Director::ProblemResolver do
  let(:subject) { described_class.new(deployment) }
  let(:deployment) { BDM::Deployment.make(name: 'mycloud') }

  let(:auto_resolution) { 'auto_resolution' }
  let(:outofsyncvm_handler) {
    double(Bosh::Director::ProblemHandlers::OutOfSyncVm, auto_resolution: auto_resolution)
  }
  let(:outofsyncvm_problem) {
    BDM::DeploymentProblem.make(deployment_id: deployment.id, resource_id: 'resource-id',
                                type: 'out_of_sync_vm', state: 'open')
  }
  let(:outofsyncvm_resolution) { 'delete_vm' }
  let(:inactivedisk_handler) {
    double(Bosh::Director::ProblemHandlers::InactiveDisk, auto_resolution: auto_resolution)
  }
  let(:inactivedisk_problem) {
    BDM::DeploymentProblem.make(deployment_id: deployment.id, resource_id: 'resource-id',
                                type: 'inactive_disk', state: 'open')
  }
  let(:inactivedisk_resolution) { 'delete_disk' }

  before do
    Bosh::Director::ProblemHandlers::InactiveDisk.stub(:new).and_return(inactivedisk_handler)
    Bosh::Director::ProblemHandlers::OutOfSyncVm.stub(:new).and_return(outofsyncvm_handler)
  end

  describe :apply_resolutions do
    it 'should raise an exception if resolution is not found' do
      problems = { outofsyncvm_problem.id.to_s => outofsyncvm_resolution }

      expect do
        subject.apply_resolutions({})
      end.to raise_error(Bosh::Director::CloudcheckResolutionNotProvided, /is not provided/)
    end

    it 'should apply resolutions' do
      problems = { outofsyncvm_problem.id.to_s  => outofsyncvm_resolution,
                   inactivedisk_problem.id.to_s => inactivedisk_resolution }

      outofsyncvm_handler.should_receive(:job=)
      outofsyncvm_handler.should_receive(:resolution_plan).with(outofsyncvm_resolution)
      outofsyncvm_handler.should_receive(:apply_resolution).with(outofsyncvm_resolution)

      inactivedisk_handler.should_receive(:job=)
      inactivedisk_handler.should_receive(:resolution_plan).with(inactivedisk_resolution)
      inactivedisk_handler.should_receive(:apply_resolution).with(inactivedisk_resolution)

      expect(subject.apply_resolutions(problems)).to eql(problems.size)
      expect(BDM::DeploymentProblem.filter(state: 'open').count).to eql(0)
    end

    it 'should apply auto resolutions' do
      problems = { outofsyncvm_problem.id.to_s  => nil,
                   inactivedisk_problem.id.to_s => inactivedisk_resolution }

      outofsyncvm_handler.should_receive(:job=)
      outofsyncvm_handler.should_receive(:resolution_plan).with(auto_resolution)
      outofsyncvm_handler.should_receive(:apply_resolution).with(auto_resolution)

      inactivedisk_handler.should_receive(:job=)
      inactivedisk_handler.should_receive(:resolution_plan).with(inactivedisk_resolution)
      inactivedisk_handler.should_receive(:apply_resolution).with(inactivedisk_resolution)

      expect(subject.apply_resolutions(problems)).to eql(problems.size)
      expect(BDM::DeploymentProblem.filter(state: 'open').count).to eql(0)
    end

    context 'failed resolutions' do
      let(:problems) {
        { outofsyncvm_problem.id.to_s  => outofsyncvm_resolution,
          inactivedisk_problem.id.to_s => inactivedisk_resolution }
      }

      before do
        outofsyncvm_handler.should_receive(:job=)
        outofsyncvm_handler.should_receive(:resolution_plan).with(outofsyncvm_resolution)

        inactivedisk_handler.should_receive(:job=)
        inactivedisk_handler.should_receive(:resolution_plan).with(inactivedisk_resolution)
        inactivedisk_handler.should_receive(:apply_resolution).with(inactivedisk_resolution)
      end

      it 'should count & mark as solved problem handler exceptions' do
        outofsyncvm_handler.should_receive(:apply_resolution).with(outofsyncvm_resolution)
                           .and_raise(Bosh::Director::ProblemHandlerError, 'Problem applying resolution')

        expect(subject.apply_resolutions(problems)).to eql(problems.size)
        expect(BDM::DeploymentProblem.filter(state: 'open').count).to eql(0)
      end

      it 'should not count not mark as solved other exceptions' do
        outofsyncvm_handler.should_receive(:apply_resolution).with(outofsyncvm_resolution)
                           .and_raise(SystemCallError, 'System error')

        expect(subject.apply_resolutions(problems)).to eql(problems.size - 1)
        expect(BDM::DeploymentProblem.filter(state: 'open').count).to eql(1)
      end
    end

    context 'ignored problems' do
      context 'when problem has a malformed id' do
        it 'should ignore problem' do
          subject.should_receive(:track_and_log).with('Ignoring problem fake-problem-1 (malformed id)')

          expect(subject.apply_resolutions({ 'fake-problem-1' => nil })).to eql(0)
        end
      end

      context 'when problem is not found' do
        it 'should ignore problem' do
          subject.should_receive(:track_and_log).with('Ignoring problem 666 (not found)')

          expect(subject.apply_resolutions({ '666' => nil })).to eql(0)
        end
      end

      context 'when problem state is close' do
        let(:closed_problem) {
          BDM::DeploymentProblem.make(deployment_id: deployment.id, resource_id: 'resource-id',
                                      type: 'out_of_sync_vm', state: 'closed')
        }

        it 'should ignore problem' do
          subject.should_receive(:track_and_log).with("Ignoring problem #{closed_problem.id.to_s} (state is 'closed')")

          expect(subject.apply_resolutions({ closed_problem.id.to_s => nil })).to eql(0)
        end
      end

      context 'when problem is not part of deployment' do
        let(:deployment2) { BDM::Deployment.make(name: 'mycloud2') }
        let(:otherdeployment_problem) {
          BDM::DeploymentProblem.make(deployment_id: deployment2.id, resource_id: 'resource-id',
                                      type: 'out_of_sync_vm', state: 'open')
        }

        it 'should ignore problem' do
          subject.should_receive(:track_and_log)
                 .with("Ignoring problem #{otherdeployment_problem.id.to_s} (not a part of this deployment)")

          expect(subject.apply_resolutions({ otherdeployment_problem.id.to_s => nil })).to eql(0)
        end
      end
    end
  end
end
