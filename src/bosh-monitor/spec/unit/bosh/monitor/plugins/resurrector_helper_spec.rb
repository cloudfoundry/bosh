require 'spec_helper'

module Bosh::Monitor::Plugins::ResurrectorHelper
  describe AlertTracker do
    subject(:tracker) { AlertTracker.new(config) }
    let(:config) do
      {}
    end
    let(:agents) { build_agents(10) }
    let(:alerts) { 0 }
    let(:deployment) { 'deployment' }

    describe '#state_for' do
      before do
        instance_manager = double(Bhm::InstanceManager)
        allow(instance_manager).to receive(:get_agents_for_deployment).with('deployment').and_return(agents)
        allow(instance_manager).to receive(:get_deleted_agents_for_deployment).with('deployment').and_return({})
        allow(Bhm).to receive_messages(instance_manager: instance_manager)

        alerts.times do |i|
          alert = double(Bosh::Monitor::Events::Alert, created_at: Time.now, severity: :critical)
          tracker.record(build_key(i), alert)
        end
      end

      context 'when the number of unresponsive agents is 0' do
        it 'reports as "normal"' do
          state = tracker.state_for(deployment)
          expect(state).to be_normal
          expect(state.summary).to eq("deployment: 'deployment'; 0 of 10 agents are unhealthy (0.0%)")
        end
      end

      context 'when the number of unresponsive agents is below the meltdown count threshold' do
        let(:config) do
          { 'minimum_down_jobs' => 2, 'percent_threshold' => 0.0 }
        end
        let(:alerts) { 1 }

        it 'reports as "managed"' do
          state = tracker.state_for(deployment)
          expect(state).to be_managed
          expect(state.summary).to eq("deployment: 'deployment'; 1 of 10 agents are unhealthy (10.0%)")
        end
      end

      context 'when the number of unresponsive agents is at/above the meltdown count threshold' do
        context 'and below the percent threshold' do
          let(:config) do
            { 'minimum_down_jobs' => 2, 'percent_threshold' => 0.21 }
          end
          let(:alerts) { 2 }

          it 'reports as "managed"' do
            state = tracker.state_for(deployment)
            expect(state).to be_managed
            expect(state.summary).to eq("deployment: 'deployment'; 2 of 10 agents are unhealthy (20.0%)")
          end
        end

        context 'and at/above the percent threshold' do
          let(:config) do
            { 'minimum_down_jobs' => 2, 'percent_threshold' => 0.20 }
          end
          let(:alerts) { 2 }

          it 'reports as "meltdown"' do
            state = tracker.state_for(deployment)
            expect(state).to be_meltdown
            expect(state.summary).to eq("deployment: 'deployment'; 2 of 10 agents are unhealthy (20.0%)")
          end
        end
      end

      context 'when recorded alerts are outside of the time threshold' do
        let(:config) do
          { 'minimum_down_jobs' => 2, 'time_threshold' => 600 }
        end
        let(:alerts) { 0 }

        it 'excludes those alerts' do
          now = Time.now
          tracker.record(build_key(0), double(Bosh::Monitor::Events::Alert, created_at: (now - 610), severity: :critical))
          tracker.record(build_key(1), double(Bosh::Monitor::Events::Alert, created_at: (now - 600), severity: :critical))
          tracker.record(build_key(2), double(Bosh::Monitor::Events::Alert, created_at: (now - 60), severity: :critical))

          state = tracker.state_for(deployment)
          expect(state).to be_meltdown
          expect(state.summary).to eq("deployment: 'deployment'; 2 of 10 agents are unhealthy (20.0%)")
        end
      end

      def build_agents(count)
        {}.tap do |result|
          count.times do |i|
            result["00#{i}"] = Bhm::Agent.new("00#{i}", deployment: 'deployment', job: "00#{i}", instance_id: "uuid#{i}")
          end
        end
      end

      def build_key(num)
        Bhm::Plugins::ResurrectorHelper::JobInstanceKey.new('deployment', "00#{num}", "uuid#{num}")
      end
    end
  end

  describe JobInstanceKey do
    it 'hashes properly' do
      key1 = described_class.new('deployment', 'job', 'uuid0')
      key2 = described_class.new('deployment', 'job', 'uuid0')
      hash = { key1 => 'foo' }

      expect(hash[key2]).to eq('foo')
    end
  end
end
