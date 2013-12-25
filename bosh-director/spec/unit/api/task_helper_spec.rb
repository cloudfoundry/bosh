require 'spec_helper'

module Bosh::Director
  describe Api::TaskHelper do
    describe '#create_task' do
      let(:tmpdir) { Dir.mktmpdir }
      after { FileUtils.rm_rf tmpdir }

      let(:user) { Models::User.make }
      let(:type) { 'type' }
      let(:description) { 'description' }
      let(:config) { Psych.load_file(asset('test-director-config.yml')) }
      let(:task_remover) { instance_double('Bosh::Director::Api::TaskRemover') }

      before do
        Config.configure(config)
        Config.base_dir = tmpdir
        Config.max_tasks = 2
        Api::TaskRemover.stub(:new).and_return(task_remover)
        task_remover.stub(:remove)
      end


      it 'should create the task debug output file' do
        task = described_class.new.create_task(user.username, type, description)
        expect(File.exists?(File.join(tmpdir, 'tasks', task.id.to_s, 'debug'))).to be(true)
      end

      it 'should create a new task model' do
        expect {
          described_class.new.create_task(user.username, type, description)
        }.to change {
          Models::Task.count
        }.from(0).to(1)
      end

      it 'should clean up old tasks' do
        logger = instance_double('Logger').as_null_object
        Logger.stub(:new).and_return(logger)

        Api::TaskRemover.should_receive(:new).with(Config.max_tasks, logger).and_return(task_remover)
        task_remover.should_receive(:remove)

        described_class.new.create_task(user.username, type, description)
      end
    end
  end
end
