require 'spec_helper'

module Bosh::Director
  describe Jobs::ScheduledOrphanedNetworkCleanup do
    subject { described_class.new(*params) }
    let(:params) do
      [{
        'max_orphaned_age_in_days' => max_orphaned_age_in_days,
      }]
    end
    let(:max_orphaned_age_in_days) { 1 }
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory) }
    let(:time) { Time.now }
    let(:one_day_seconds) { 24 * 60 * 60 }
    let(:one_day_one_second_ago) { time - one_day_seconds - 1 }
    let(:less_than_one_day_ago) { time - one_day_seconds + 1 }

    let!(:orphan_network_1) do
      Models::Network.make(
        name: 'nw-1',
        orphaned: true,
        orphaned_at: one_day_one_second_ago,
        created_at: one_day_one_second_ago,
      )
    end

    let!(:orphan_network_2) do
      Models::Network.make(
        name: 'nw-2',
        orphaned: true,
        orphaned_at: less_than_one_day_ago,
        created_at: one_day_one_second_ago,
      )
    end

    let!(:network_3) do
      Models::Network.make(
        name: 'nw-3',
        orphaned: false,
        orphaned_at: one_day_one_second_ago,
        created_at: one_day_one_second_ago,
      )
    end

    let(:task) { Models::Task.make(id: 42) }
    let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, task.id) }
    let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }
    let(:event_manager) { Api::EventManager.new(true) }
    let(:task) { Bosh::Director::Models::Task.make(id: 42, username: 'user') }

    let(:scheduled_orphaned_network_cleanup_job) do
      instance_double(
        Bosh::Director::Jobs::ScheduledOrphanedNetworkCleanup,
        username: 'user',
        task_id: task.id,
        event_manager: event_manager,
      )
    end

    before do
      allow(Bosh::Director::CloudFactory).to receive(:create).and_return(cloud_factory)
      allow(cloud_factory).to receive(:get).with('').and_return(cloud)
      allow(Config).to receive(:current_job).and_return(scheduled_orphaned_network_cleanup_job)
    end

    describe '#has_work' do
      describe 'when there is work to do' do
        it 'should return true' do
          expect(described_class.has_work(params)).to eq(true)
        end
      end

      describe 'when there is no work to do' do
        let(:max_orphaned_age_in_days) { 2 }

        it 'should return false' do
          expect(described_class.has_work(params)).to eq(false)
        end
      end
    end

    describe 'performing the job' do
      before do
        allow(Time).to receive(:now).and_return(time)
        allow(cloud).to receive(:delete_network).with('nw-1')
      end

      it 'deletes orphans older than days specified' do
        subject.perform
        expect(Models::Network.all.map(&:name).sort).to eq(['nw-2', 'nw-3'])
      end

      context 'when CPI is unable to delete a network' do
        let(:orphan_network_manager) { instance_double(OrphanNetworkManager) }

        before do
          allow(OrphanNetworkManager).to receive(:new).and_return(orphan_network_manager)
        end

        context 'and multiple orphan networks' do
          let(:orphan_network_2) do
            Models::Network.make(
              name: 'nw-2',
              orphaned: true,
              orphaned_at: one_day_one_second_ago,
              created_at: one_day_one_second_ago,
            )
          end

          it 'cleans all disks and raises the error thrown by the CPI' do
            allow(orphan_network_manager)
              .to receive(:delete_network)
              .with('nw-1')
              .and_raise(Bosh::Clouds::CloudError.new('Bad stuff happened!'))

            allow(orphan_network_manager)
              .to receive(:delete_network)
              .with('nw-2')

            expect { subject.perform }.to raise_error(Bosh::Clouds::CloudError, /Deleted 1 orphaned networks\(s\) older .+ Failed to delete 1 network\(s\)./)

            expect(orphan_network_manager).to have_received(:delete_network).with('nw-1')
            expect(orphan_network_manager).to have_received(:delete_network).with('nw-2')
          end
        end
      end
    end
  end
end
