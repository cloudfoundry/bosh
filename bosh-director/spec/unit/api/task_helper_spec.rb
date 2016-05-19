require 'spec_helper'

module Bosh::Director
  describe Api::TaskHelper do
    describe '#create_task' do
      let(:tmpdir) { Dir.mktmpdir }
      after { FileUtils.rm_rf tmpdir }

      let(:type) { 'type' }
      let(:description) { 'description' }
      let(:config) { SpecHelper.spec_get_director_config }
      let(:deployment_name) { 'deployment-name' }
      let(:task_remover) { instance_double('Bosh::Director::Api::TaskRemover') }
      let(:teams) do
        [Models::Team.make(name: 'security'), Models::Team.make(name: 'spies')]
      end
      let(:deployment) { Models::Deployment.create_with_teams(name: deployment_name, teams: teams) }

      before do
        Config.configure(config)
        Config.base_dir = tmpdir
        Config.max_tasks = 2
        allow(Api::TaskRemover).to receive(:new).and_return(task_remover)
        allow(task_remover).to receive(:remove)
      end

      it 'should create the task debug output file' do
        task = described_class.new.create_task('fake-user', type, description, deployment)
        expect(File.exists?(File.join(tmpdir, 'tasks', task.id.to_s, 'debug'))).to be(true)
      end

      it 'should create a new task model' do
        expect {
          described_class.new.create_task('fake-user', type, description, deployment)
        }.to change {
          Models::Task.count
        }.from(0).to(1)
      end

      it 'should clean up old tasks of the given type' do
        expect(Api::TaskRemover).to receive(:new).with(Config.max_tasks).and_return(task_remover)
        expect(task_remover).to receive(:remove).with(type)

        described_class.new.create_task('fake-user', type, description, deployment)
      end

      it 'logs director version' do
        task = described_class.new.create_task('fake-user', type, description, deployment)
        director_version_line, enqueuing_task_line = File.read(File.join(tmpdir, 'tasks', task.id.to_s, 'debug')).split(/\n/)
        expect(director_version_line).to match(/INFO .* Director Version: #{Bosh::Director::VERSION}/)
        expect(enqueuing_task_line).to match(/INFO .* Enqueuing task: #{task.id}/)
      end

      it 'persists deployment teams on the task so that they can be referenced even when the deployment database record has been deleted' do
        expect {
          described_class.new.create_task('fake-user', type, description, deployment)
        }.to change {
          Models::Task.where(teams: teams).count
        }.from(0).to(1)
      end

      it 'does not reference teams when task is not deployment-specific' do
        expect(described_class.new.create_task('fake-user', type, description, nil).teams).to be_empty
      end
    end
  end
end
