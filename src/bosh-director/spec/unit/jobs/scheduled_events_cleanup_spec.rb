require 'spec_helper'

module Bosh::Director
  describe Jobs::ScheduledEventsCleanup do
    subject(:job) { described_class.new(*params) }
    let(:params) do
      [{
          'max_events' => max_events,
      }]
    end
    let(:max_events) { 2 }

    def make_n_events(num_events)
      num_events.times do |i|
        FactoryBot.create(:models_event)
      end
    end

    describe 'DJ class expectations' do
      let(:job_type) { :scheduled_events_cleanup }
      let(:queue) { :normal }
      it_behaves_like 'a DJ job'
    end


    describe '#has_work' do
      describe 'when there is work to do' do
        it 'should return true' do
          make_n_events(3)
          expect(described_class.has_work(params)).to eq(true)
        end
      end

      describe 'when there is no work to do' do
        it 'should return false' do
          make_n_events(2)
          expect(described_class.has_work(params)).to eq(false)
        end
      end
    end

    describe 'performing the job' do
      it 'deletes old events' do
        make_n_events(3)
        job.perform
        expect(Models::Event.count).to eq(2)
      end

      it 'should log' do
        make_n_events(3)
        expect(subject.perform).to eq("Old events were deleted")
      end
    end
  end
end
