require 'spec_helper'

describe Bhm::Plugins::ResurrectorHelper::AlertTracker do
  describe '#melting_down?' do
    let(:agents) {
      agents = {}
      100.times.each do |i|
        agents["00#{i}"]= Bhm::Agent.new("00#{i}", deployment: 'deployment', job: "00#{i}", instance_id: "uuid#{i.to_s}")
      end
      agents
    }

    let(:job_instance_keys) {
      100.times.map do |i|
        Bhm::Plugins::ResurrectorHelper::JobInstanceKey.new('deployment', "00#{i}", "uuid#{i.to_s}")
      end
    }

    before do
      mock_instance_manager = double(Bhm::InstanceManager)
      allow(mock_instance_manager).to receive(:get_agents_for_deployment).with('deployment').and_return(agents)
      allow(Bhm).to receive_messages(instance_manager: mock_instance_manager)
    end

    it 'is melting down if more than 30% of agents are down' do
      alert_tracker = described_class.new('percent_threshold' => 0.3)
      31.times { |i| alert_tracker.record(job_instance_keys[i], Time.now) }

      expect(alert_tracker.melting_down?('deployment')).to be(true)
    end

    it 'is not melting down if less than 30% of agents are down' do
      alert_tracker = described_class.new('percent_threshold' => 0.3)
      29.times { |i| alert_tracker.record(job_instance_keys[i], Time.now) }

      expect(alert_tracker.melting_down?('deployment')).to be(false)
    end

    it 'is not melting down if less than 7 agents are down' do
      alert_tracker = described_class.new('minimum_down_jobs' => 7, 'percent_threshold' => 0.01)
      6.times { |i| alert_tracker.record(job_instance_keys[i], Time.now) }

      expect(alert_tracker.melting_down?('deployment')).to be(false)
    end

    it 'is not melting down if all agents are responding' do
      alert_tracker = described_class.new('percent_threshold' => 0.0)

      expect(alert_tracker.melting_down?('deployment')).to be(false)
    end
  end
end

describe Bhm::Plugins::ResurrectorHelper::JobInstanceKey do
  it 'hashes properly' do
    key1 = described_class.new('deployment', 'job', 'uuid0')
    key2 = described_class.new('deployment', 'job', 'uuid0')
    hash = { key1 => 'foo' }

    expect(hash[key2]).to eq('foo')
  end
end
