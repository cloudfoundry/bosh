require 'spec_helper'

module Bosh::Monitor
  describe 'Agent alert identity' do
    let(:processor) { double('processor') }
    let(:manager) do
      InstanceManager.allocate.tap do |manager|
        manager.instance_variable_set(:@processor, processor)
        manager.instance_variable_set(:@alerts_processed, 0)
      end
    end
    let(:agent) { double('agent', name: 'agent-name', deployment: 'owned', job: 'job', instance_id: 'instance') }

    it 'binds an alert with a supplied source to the authenticated agent deployment' do
      message = { 'source' => 'monit', 'deployment' => 'victim', 'job' => 'victim-job', 'instance_id' => 'victim-id' }
      expect(processor).to receive(:process).with(:alert, { 'source' => 'monit', 'deployment' => 'owned', 'job' => 'job', 'instance_id' => 'instance' })
      manager.send(:on_alert, agent, message)
    end

    it 'drops agent-supplied jobs_to_instance_ids so agents cannot target other instances' do
      message = {
        'category' => 'deployment_health',
        'jobs_to_instance_ids' => { 'other-job' => ['other-instance'] },
      }
      expect(processor).to receive(:process).with(:alert, {
        'category' => 'deployment_health',
        'source' => 'agent-name',
        'deployment' => 'owned',
        'job' => 'job',
        'instance_id' => 'instance',
      })
      manager.send(:on_alert, agent, message)
    end
  end
end
