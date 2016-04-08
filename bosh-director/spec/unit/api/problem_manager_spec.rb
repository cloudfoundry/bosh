require 'spec_helper'

module Bosh::Director
  describe Api::ProblemManager do
    let(:task) { double('Task') }
    let(:deployment) { double('Deployment', name: 'mycloud') }
    let(:username) { 'username-1' }
    let(:job_queue) { instance_double('Bosh::Director::JobQueue') }

    subject(:problem_manager) { described_class.new }

    before do
      allow(JobQueue).to receive(:new).and_return(job_queue)
    end

    describe '#perform_scan' do
      it 'enqueues a task' do
        expect(job_queue).to receive(:enqueue).with(
            username, Jobs::CloudCheck::Scan, 'scan cloud', [deployment.name], deployment.name).and_return(task)
        expect(subject.perform_scan(username, deployment)).to eq(task)
      end
    end

    describe '#apply_resolutions' do
      let(:resolutions) { double('Resolutions') }

      it 'enqueues a task' do
        expect(job_queue).to receive(:enqueue).with(
            username, Jobs::CloudCheck::ApplyResolutions, 'apply resolutions',
            [deployment.name, resolutions], deployment.name).and_return(task)
        expect(subject.apply_resolutions(username, deployment, resolutions)).to eq(task)
      end
    end

    describe '#scan_and_fix' do
      let(:jobs) { double('Jobs') }

      context 'when fixing stateful nodes' do
        before do
          Bosh::Director::Config.fix_stateful_nodes = true
        end

        it 'enqueues a task' do
          expect(job_queue).to receive(:enqueue).with(
              username, Jobs::CloudCheck::ScanAndFix, 'scan and fix',
              [deployment.name, jobs, true], deployment.name).and_return(task)
          expect(subject.scan_and_fix(username, deployment, jobs)).to eq(task)
        end
      end

      context 'when not fixing stateful nodes' do
        before do
          Bosh::Director::Config.fix_stateful_nodes = false
        end

        it 'enqueues a task' do
          expect(job_queue).to receive(:enqueue).with(
              username, Jobs::CloudCheck::ScanAndFix, 'scan and fix',
              [deployment.name, jobs, false], deployment.name).and_return(task)
          expect(subject.scan_and_fix(username, deployment, jobs)).to eq(task)
        end
      end
    end
  end
end
