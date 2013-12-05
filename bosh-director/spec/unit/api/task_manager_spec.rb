require 'spec_helper'

describe Bosh::Director::Api::TaskManager do
  let(:manager) { described_class.new }

  describe '#decompress' do
    it 'should decompress a .gz file' do
      Dir.mktmpdir do |dir|
        FileUtils.cp(asset('foobar.gz'), dir)
        src = File.join(dir, 'foobar.gz')
        dst = File.join(dir, 'foobar')

        File.exists?(dst).should be(false)

        manager.decompress(src, dst)

        File.exists?(dst).should be(true)
      end
    end

    it 'should not decompress if an uncompressed file exist' do
      Dir.mktmpdir do |dir|
        file = File.join(dir, 'file')
        file_gz = File.join(dir, 'file.gz')
        FileUtils.touch(file)
        FileUtils.touch(file_gz)

        File.should_not_receive(:open)

        manager.decompress(file_gz, file)
      end
    end
  end

  describe '#task_file' do
    let(:task) { task = double(Bosh::Director::Models::Task) }
    let(:task_dir) { '/var/vcap/store/director/tasks/1' }

    context 'backward compatibility' do
      it 'should return the task output contents if the task output contents is not a directory' do
        task.stub(output: 'task output')

        manager.log_file(task, 'type').should == 'task output'
      end

      it 'should return the cpi log when the soap log does not exist' do
        manager.stub(:decompress)
        task.stub(output: task_dir)
        File.should_receive(:directory?).with(task_dir).and_return(true)
        File.should_receive(:file?).with(File.join(task_dir, 'soap')).and_return(false)

        manager.log_file(task, 'soap').should match(%{/cpi})
      end

      it 'should return the soap log if it exist' do
        manager.stub(:decompress)
        task.stub(output: task_dir)
        File.should_receive(:directory?).with(task_dir).and_return(true)
        File.should_receive(:file?).with(File.join(task_dir, 'soap')).and_return(true)

        manager.log_file(task, 'cpi').should match(%{/soap})
      end
    end

    it 'should return the task log path' do
      task.stub(output: task_dir)
      manager.stub(:decompress)

      File.should_receive(:directory?).with(task_dir).and_return(true)
      File.should_receive(:file?).with(File.join(task_dir, 'soap')).and_return(false)

      manager.log_file(task, 'cpi')
    end
  end
end
