require 'spec_helper'

module Bosh::Monitor::Plugins::ResurrectorHelper
  describe AlertTracker do
    subject(:tracker) { AlertTracker.new(config) }
    let(:config) { {} }
    let(:agents) { build_agents(10) }
    let(:alerts) { 0 }
    let(:deployment) { 'deployment'}

    describe '#state_for' do
      before do
        instance_manager = double(Bhm::InstanceManager)
        allow(instance_manager).to receive(:get_agents_for_deployment).with('deployment').and_return(agents)
        allow(Bhm).to receive_messages(instance_manager: instance_manager)

        alerts.times { |i| tracker.record(build_key(i), Time.now) }
      end

      context 'when the number of unresponsive agents is 0' do
        it 'reports as "normal"' do
          state, details = tracker.state_for(deployment)
          expect(state).to be(AlertTracker::STATE_NORMAL)
          expect(details).to eq({
            'deployment' => 'deployment',
            'alerts' => { 'count' => 0, 'percent' => '0.0%' }
          })
        end
      end

      context 'when the number of unresponsive agents is below the meltdown count threshold' do
        let(:config) { { 'count_threshold' => 2, 'percent_threshold' => 0.0 } }
        let(:alerts) { 1 }

        it 'reports as "managed"' do
          state, details = tracker.state_for(deployment)
          expect(state).to be(AlertTracker::STATE_MANAGED)
          expect(details).to eq({
            'deployment' => deployment,
            'alerts' => { 'count' => 1, 'percent' => '10.0%' }
          })
        end
      end

      context 'when the number of unresponsive agents is at/above the meltdown count threshold' do
        context 'and below the percent threshold' do
          let(:config) { { 'count_threshold' => 2, 'percent_threshold' => 0.21 } }
          let(:alerts) { 2 }

          it 'reports as "managed"' do
            state, details = tracker.state_for(deployment)
            expect(state).to be(AlertTracker::STATE_MANAGED)
            expect(details).to eq({
              'deployment' => deployment,
              'alerts' => { 'count' => 2, 'percent' => '20.0%' }
            })
          end
        end

        context 'and at/above the percent threshold' do
          let(:config) { { 'count_threshold' => 2, 'percent_threshold' => 0.20 } }
          let(:alerts) { 2 }

          it 'reports as "meltdown"' do
            state, details = tracker.state_for(deployment)
            expect(state).to be(AlertTracker::STATE_MELTDOWN)
            expect(details).to eq({
              'deployment' => deployment,
              'alerts' => { 'count' => 2, 'percent' => '20.0%' }
            })
          end
        end
      end

      context 'when recorded alerts are outside of the time threshold' do
        let(:config) { { 'count_threshold' => 2, 'time_threshold' => 600 } }
        let(:alerts) { 0 }

        it 'excludes those alerts' do
          now = Time.now
          tracker.record(build_key(0), now - 610)
          tracker.record(build_key(1), now - 600)
          tracker.record(build_key(2), now - 60)

          state, details = tracker.state_for(deployment)
          expect(state).to be(AlertTracker::STATE_MELTDOWN)
          expect(details).to eq({
            'deployment' => deployment,
            'alerts' => { 'count' => 2, 'percent' => '20.0%' }
          })
        end
      end

      def build_agents(count)
        {}.tap do |result|
          count.times { |i| result["00#{i}"]= Bhm::Agent.new("00#{i}", deployment: 'deployment', job: "00#{i}", instance_id: "uuid#{i.to_s}") }
        end
      end

      def build_key(i)
        Bhm::Plugins::ResurrectorHelper::JobInstanceKey.new('deployment', "00#{i}", "uuid#{i.to_s}")
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
