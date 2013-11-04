require 'spec_helper'
require 'bosh/director/scheduler'

module Bosh::Director
  describe Scheduler do
    let(:cloud) { double(:Cloud) }
    let(:uuid) { 'deadbeef' }
    let(:director_name) { 'Test Director' }
    let(:fake_scheduler) { instance_double('Rufus::Scheduler::PlainScheduler') }
    let(:params) {
      [
        'foo',
        'bar',
        { 'named' => 'named_value' }
      ]
    }
    let(:scheduled_jobs) {
      [
        {
          'command' => 'FakeJob',
          'schedule' => '0 1 * * *',
          'params' => params
        }
      ]
    }

    let(:queue) { double('JobQueue') }

    def make_subject(jobs=scheduled_jobs, overrides={})
      opts = {
        scheduler: fake_scheduler,
        cloud: cloud,
        queue: queue
      }.merge(overrides)

      described_class.new(jobs, opts)
    end

    before do
      fake_scheduler.stub(:start)
      fake_scheduler.stub(:join)

      Config.stub(:uuid).and_return(uuid)
      Config.stub(:name).and_return(director_name)
      Config.stub(:enable_snapshots).and_return(true)
    end

    module Jobs
      class FakeJob
      end
    end

    describe 'scheduling jobs' do
      it 'schedules jobs at the appropriate time' do
        subject = make_subject
        fake_scheduler.should_receive(:cron).with('0 1 * * *').
          and_yield(double('Job', next_time: 'tomorrow'))

        queue.should_receive(:enqueue).with('scheduler', Jobs::FakeJob, 'scheduled FakeJob', params)

        subject.start!
      end

      it 'do not schedule jobs if scheduled_jobs is nil' do
        subject = make_subject(nil)
        fake_scheduler.should_not_receive(:cron)
        subject.start!
      end

      it 'do not schedule jobs if scheduled_jobs is empty' do
        subject = make_subject([])
        fake_scheduler.should_not_receive(:cron)
        subject.start!
      end

      it 'raises if scheduled_jobs is not an Array' do
        expect { make_subject({}) }.to raise_error('scheduled_jobs must be an array')
      end
    end
  end
end
