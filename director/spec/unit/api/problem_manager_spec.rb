# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::Director::Api::ProblemManager do
  let(:task) { double('Task', id: 42) }
  let(:deployment) { double('Deployment', name: 'mycloud') }
  let(:deployment_manager) { double('Deployment subject', find_by_name: deployment) }
  subject { described_class.new(deployment_manager) }

  before do
    BD::JobQueue.any_instance.stub(create_task: task)
  end

  describe '#perform_scan' do
    it 'returns a task' do
      Resque.stub(:enqueue)

      expect(subject.perform_scan('admin', deployment.name)).to eq(task)
    end

    it 'enqueues a task' do
      Resque.should_receive(:enqueue).with(BD::Jobs::CloudCheck::Scan, task.id, deployment.name)

      subject.perform_scan('admin', deployment.name)
    end
  end

  pending '#get_problems'

  describe '#apply_resolutions' do
    it 'returns a task' do
      Resque.stub(:enqueue)

      expect(subject.apply_resolutions('admin', deployment.name, 'FAKE RESOLUTIONS')).to eq(task)
    end

    it 'enqueues a task' do
      Resque.should_receive(:enqueue).with(BD::Jobs::CloudCheck::ApplyResolutions, task.id, deployment.name, 'FAKE RESOLUTIONS')

      subject.apply_resolutions('admin', deployment.name, 'FAKE RESOLUTIONS')
    end
  end

  describe '#scan_and_fix' do
    context 'when fixing stateful nodes' do
      before :each do
        Bosh::Director::Config.fix_stateful_nodes = true
      end

      it 'returns a task' do
        Resque.stub(:enqueue)

        expect(subject.scan_and_fix('admin', deployment.name, [])).to eq task
      end

      it 'enqueues a task' do
        Resque.should_receive(:enqueue).with(BD::Jobs::CloudCheck::ScanAndFix, task.id, deployment.name, [], true)
        subject.scan_and_fix('admin', deployment.name, [])
      end
    end

    context 'when not fixing stateful nodes' do
      before :each do
        Bosh::Director::Config.fix_stateful_nodes = false
      end

      it 'returns a task' do
        Resque.stub(:enqueue)

        expect(subject.scan_and_fix('admin', deployment.name, [])).to eq task
      end

      it 'enqueues a task' do
        Resque.should_receive(:enqueue).with(BD::Jobs::CloudCheck::ScanAndFix, task.id, deployment.name, [], false)
        subject.scan_and_fix('admin', deployment.name, [])
      end
    end
  end
end
