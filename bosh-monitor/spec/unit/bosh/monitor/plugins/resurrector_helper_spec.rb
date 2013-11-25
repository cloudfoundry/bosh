require 'spec_helper'

describe Bhm::Plugins::ResurrectorHelper::AlertTracker do
  describe '#melting_down?' do
    let(:agents) {
      agents = {}
      100.times.each do |i|
        agents["00#{i}"]= Bhm::Agent.new("00#{i}", deployment: 'deployment', job: "00#{i}", index: i.to_s)
      end
      agents
    }

    let(:job_instance_keys) {
      100.times.map do |i|
        Bhm::Plugins::ResurrectorHelper::JobInstanceKey.new('deployment', "00#{i}", i.to_s)
      end
    }

    before do
      mock_agent_manager = double(Bhm::AgentManager)
      mock_agent_manager.stub(:get_agents_for_deployment).with('deployment').and_return(agents)
      Bhm.stub(agent_manager: mock_agent_manager)
    end

    it 'is melting down if more than 30% of agents are down' do
      alert_tracker = described_class.new('percent_threshold' => 0.3)
      31.times { |i| alert_tracker.record(job_instance_keys[i], Time.now) }

      alert_tracker.melting_down?('deployment').should be(true)
    end

    it 'is not melting down if less than 30% of agents are down' do
      alert_tracker = described_class.new('percent_threshold' => 0.3)
      29.times { |i| alert_tracker.record(job_instance_keys[i], Time.now) }

      alert_tracker.melting_down?('deployment').should be(false)
    end

    it 'is not melting down if less than 7 agents are down' do
      alert_tracker = described_class.new('minimum_down_jobs' => 7, 'percent_threshold' => 0.01)
      6.times { |i| alert_tracker.record(job_instance_keys[i], Time.now) }

      alert_tracker.melting_down?('deployment').should be(false)
    end
    
    it 'is not melting down if all agents are responding' do
      alert_tracker = described_class.new('percent_threshold' => 0.0)

      alert_tracker.melting_down?('deployment').should be(false)
    end
  end
end

describe Bhm::Plugins::ResurrectorHelper::JobInstanceKey do
  it 'hashes properly' do
    key1 = described_class.new('deployment', 'job', 0)
    key2 = described_class.new('deployment', 'job', 0)
    hash = { key1 => 'foo' }

    hash[key2].should == 'foo'
  end
end
