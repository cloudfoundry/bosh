require 'spec_helper'

module Bosh::Director
  describe Api::TaskHelper do
    class TaskHelperClass
      include Bosh::Director::Api::TaskHelper
    end

    describe '#create_task' do
      let(:tmpdir) { Dir.mktmpdir }
      let(:user) { Models::User.make }
      let(:type) { 'type' }
      let(:description) { 'description' }
      let(:config) { Psych.load_file(asset('test-director-config.yml')) }

      before do
        Config.configure(config)
        Config.base_dir = tmpdir
        Config.max_tasks = 2
      end

      after do
        FileUtils.rm_rf tmpdir
      end

      it 'should create the task output file' do
        task = TaskHelperClass.new.create_task(user.username, type, description)
        expect(File.exists?(File.join(tmpdir, 'tasks', task.id.to_s, 'debug'))).to be(true)
      end

      it 'should create a new task model' do
        TaskHelperClass.new.create_task(user.username, type, description)
        Models::Task.count.should == 1
      end

      it 'should clean up old tasks' do
        3.times {
          TaskHelperClass.new.create_task(user.username, type, description)
        }
        Models::Task.count.should == 2

        Dir.glob(File.join(tmpdir, 'tasks', '*')).size.should == 2
      end
    end
  end
end
