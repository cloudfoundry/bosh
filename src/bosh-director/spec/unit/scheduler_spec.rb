require 'spec_helper'
require 'bosh/director/scheduler'

module Bosh::Director
  describe Scheduler do
    let(:scheduler) { described_class.new(scheduled_jobs, opts) }
    let(:scheduled_jobs) do
      [
        {
          'command' => job_name,
          'schedule' => '0 1 * * *',
          'params' => params,
        },
      ]
    end
    let(:opts) do
      {
        scheduler: fake_scheduler,
        cloud: cloud,
        queue: queue,
      }
    end
    let(:cloud) { double(:Cloud) }
    let(:uuid) { 'deadbeef' }
    let(:job_name) { 'FakeJob' }
    let(:queue) { double('JobQueue') }
    let(:director_name) { 'Test Director' }
    let(:fake_scheduler) { instance_double('Rufus::Scheduler') }
    let(:params) do
      [
        'foo',
        'bar',
        { 'named' => 'named_value' },
      ]
    end

    before do
      allow(Config).to receive(:uuid).and_return(uuid)
      allow(Config).to receive(:name).and_return(director_name)
      allow(Config).to receive(:enable_snapshots).and_return(true)
    end

    module Jobs
      class FakeJob
      end
    end

    module Jobs
      class FakeJobWithScheduleMessage
        def self.schedule_message
          'class with schedule message'
        end
      end
    end

    module Jobs
      class FakeJobNoWork
        def self.has_work(_params)
          false
        end
      end
    end

    module Jobs
      class FakeJobHasWork
        def self.has_work(_params)
          true
        end
      end
    end

    describe 'scheduling jobs' do
      it 'schedules jobs at the appropriate time' do
        expect(fake_scheduler).to receive(:cron).with('0 1 * * *')
                                                .and_yield(double('Job', next_time: 'tomorrow'))
        expect(queue).to receive(:enqueue).with('scheduler', Jobs::FakeJob, 'scheduled FakeJob', params)

        scheduler.start!
      end

      describe 'when scheduled jobs are nil' do
        let(:scheduled_jobs) { nil }
        it 'does not schedule jobs' do
          expect(fake_scheduler).not_to receive(:cron)
          scheduler.start!
        end
      end

      describe 'when scheduled jobs are emtpy' do
        let(:scheduled_jobs) { [] }
        it 'does not schedule jobs' do
          expect(fake_scheduler).not_to receive(:cron)
          scheduler.start!
        end
      end

      describe 'when scheduled jobs is not an Array' do
        let(:scheduled_jobs) do
          {}
        end
        it 'raises' do
          expect { scheduler }.to raise_error('scheduled_jobs must be an array')
        end
      end

      describe 'scheduling jobs with a custom schedule message' do
        let(:job_name) { 'FakeJobWithScheduleMessage' }
        it 'sends the scheduled message' do
          expect(fake_scheduler).to receive(:cron).with('0 1 * * *')
                                                  .and_yield(double('Job', next_time: 'tomorrow'))

          expect(queue).to receive(:enqueue).with('scheduler', Jobs::FakeJobWithScheduleMessage, 'class with schedule message', params)

          scheduler.start!
        end
      end

      describe 'conditional enqueueing' do
        before { allow(fake_scheduler).to receive(:cron).and_yield(double('Job')) }

        describe 'when the job class does not respond to #has_work' do
          let(:job_name) { 'FakeJobWithScheduleMessage' }
          it 'should enqueue' do
            expect(queue).to receive(:enqueue)
            scheduler.start!
          end
        end

        describe 'when the job class responds to #has_work' do
          let(:job_name) { 'FakeJobHasWork' }

          it 'sends the job params to the job #has_work method' do
            allow(queue).to receive(:enqueue)
            expect(Jobs::FakeJobHasWork).to receive(:has_work).with(params).twice
            scheduler.start!
          end

          describe 'when the job class indicates it has work' do
            it 'enqueues' do
              expect(queue).to receive(:enqueue)
              scheduler.start!
            end
          end

          describe 'when the job class does not have work' do
            let(:job_name) { 'FakeJobNoWork' }
            it 'does not enqueue' do
              expect(queue).to_not receive(:enqueue)
              scheduler.start!
            end
          end
        end
      end
    end
  end
end
