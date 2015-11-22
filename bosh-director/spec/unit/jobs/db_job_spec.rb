require 'spec_helper'

module Bosh::Director
  describe Jobs::DBJob do

    let (:db_job) { Jobs::DBJob.new(job_class, task.id, args) }
    let(:job_class) do
      Class.new(Jobs::BaseJob) do
        define_method :perform do
          'foo'
        end
        @queue = :normal
      end
    end
    let(:task) { Models::Task.make(id: 42) }
    let(:args) { ["1", "2"] }

    it "doesn't accept job class that is not a subclass of base job" do
      expect {
        Jobs::DBJob.new(Class.new, task.id, args)
      }.to raise_error(DirectorError, /invalid director job/i)
    end

    it "doesn't accept job class that does not have \perform' method" do
      job_class_without_perform = Class.new(Jobs::BaseJob) do
        @queue = :normal
      end

      expect {
        Jobs::DBJob.new(job_class_without_perform, task.id, args)
      }.to raise_error(DirectorError, /invalid director job/i)
    end

    it "doesn't accept job class without queue value" do
      job_class_without_queue = Class.new(Jobs::BaseJob) do
        define_method :perform do
          'foo'
        end
      end

      expect {
        Jobs::DBJob.new(job_class_without_queue, task.id, args)
      }.to raise_error(DirectorError, /invalid director job/i)
    end

    it "performs new job" do
      expect(Jobs::BaseJob).to receive(:perform).with(task.id, *args)
      db_job.perform
    end

    it 'gets queue name from job class' do
      expect(db_job.queue_name).to eq(:normal)
    end
  end
end