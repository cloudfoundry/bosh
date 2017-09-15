require 'spec_helper'
require 'bosh/director/job_queue'

module Bosh::Director
  describe JobQueue do
    class FakeJob < Jobs::BaseJob
      def self.job_type
        :snow
      end
      define_method :perform do
        'foo'
      end
      @queue = :sample
    end

    let(:tmpdir) { Dir.mktmpdir }
    after { FileUtils.rm_rf tmpdir }

    let(:config) { SpecHelper.spec_get_director_config }
    let(:job_class) { FakeJob }
    let(:description) { 'busy doing something' }
    let(:task_remover) { instance_double('Bosh::Director::Api::TaskRemover') }

    let(:deployment_name) { 'deployment-name' }
    let(:teams) do
      [Models::Team.make(name: 'security'), Models::Team.make(name: 'spies')]
    end
    let(:deployment) { Models::Deployment.create_with_teams(name: deployment_name, teams: teams) }

    before do
      Config.configure(config)
      Config.base_dir = tmpdir
      Config.max_tasks = 2
      allow(Api::TaskRemover).to receive(:new).with(Config.max_tasks).and_return(task_remover)
      allow(task_remover).to receive(:remove)
    end

    describe '#enqueue' do
      it 'enqueues a job' do
        expect(Jobs::DBJob).to receive(:new).with(job_class, 1, ['foo', 'bar']).and_return(Jobs::DBJob.new(job_class, 1,  ['foo', 'bar']))
        expect(Delayed::Job.count).to eq(0)
        retval = subject.enqueue('whoami', job_class, description, ['foo', 'bar'], deployment)
        expect(retval.id).to eq(1)
        expect(Delayed::Job.count).to eq(1)
        expect(Delayed::Job.first[:queue]).to eq('sample')
      end

      it 'enqueues a job with a context id' do
        expect(Jobs::DBJob).to receive(:new).with(job_class, 1, ['foo', 'bar']).and_return(Jobs::DBJob.new(job_class, 1,  ['foo', 'bar']))
        expect(Delayed::Job.count).to eq(0)
        context_id = 'example-context-id'
        retval = subject.enqueue('whoami', job_class, description, ['foo', 'bar'], deployment, context_id)
        expect(retval.context_id).to eq(context_id)
      end

      it 'should clean up old tasks of the given type' do
        expect(task_remover).to receive(:remove).with(job_class.job_type)

        subject.enqueue('whoami', job_class, description, [], deployment)
      end

      it 'should clean up old log dir' do
        FileUtils.mkdir_p("#{tmpdir}/tasks/1")

        File.open("#{tmpdir}/tasks/1/debug", 'w+') do |f|
          f.write('STALE LOG')
        end

        subject.enqueue('whoami', job_class, description, [], deployment)

        expect(File.open("#{tmpdir}/tasks/1/debug").read).not_to match('STALE LOG')
      end

      it 'should create the task debug output file' do
        task = subject.enqueue('fake-user', job_class, description, [], deployment)

        expect(File.exists?(File.join(tmpdir, 'tasks', task.id.to_s, 'debug'))).to be(true)
      end

      it 'should create a new task model' do
        expect {
          subject.enqueue('fake-user', job_class, description, [], deployment)
        }.to change {
          Models::Task.count
        }.from(0).to(1)
      end

      it 'logs director version' do
        task = subject.enqueue('fake-user', job_class, description, [], deployment)
        director_version_line, enqueuing_task_line = File.read(File.join(tmpdir, 'tasks', task.id.to_s, 'debug')).split(/\n/)
        expect(director_version_line).to match(/INFO .* Director Version: 0.0.2/)
        expect(enqueuing_task_line).to match(/INFO .* Enqueuing task: #{task.id}/)
      end

      it 'persists deployment teams on the task so that they can be referenced even when the deployment database record has been deleted' do
        expect {
          subject.enqueue('fake-user', job_class, description, [], deployment)
        }.to change {
          Models::Task.where(teams: teams).count
        }.from(0).to(1)
      end

      it 'does not reference teams when task is not deployment-specific' do
        expect(subject.enqueue('fake-user', job_class, description, [], nil).teams).to be_empty
      end
    end
  end
end
