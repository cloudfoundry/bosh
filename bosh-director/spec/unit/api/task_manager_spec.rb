require 'spec_helper'

describe Bosh::Director::Api::TaskManager do
  let(:manager) { described_class.new }

  describe '#decompress' do
    it 'should decompress a .gz file' do
      Dir.mktmpdir do |dir|
        FileUtils.cp(asset('foobar.gz'), dir)
        src = File.join(dir, 'foobar.gz')
        dst = File.join(dir, 'foobar')

        expect(File.exists?(dst)).to be(false)

        manager.decompress(src, dst)

        expect(File.exists?(dst)).to be(true)
      end
    end

    it 'should not decompress if an uncompressed file exist' do
      Dir.mktmpdir do |dir|
        file = File.join(dir, 'file')
        file_gz = File.join(dir, 'file.gz')
        FileUtils.touch(file)
        FileUtils.touch(file_gz)

        expect(File).not_to receive(:open)

        manager.decompress(file_gz, file)
      end
    end
  end

  describe '#task_file' do
    let(:task) { task = double(Bosh::Director::Models::Task) }
    let(:task_dir) { '/var/vcap/store/director/tasks/1' }

    context 'backward compatibility' do
      it 'should return the task output contents if the task output contents is not a directory' do
        allow(task).to receive_messages(output: 'task output')

        expect(manager.log_file(task, 'type')).to eq('task output')
      end

      it 'should return the cpi log when the soap log does not exist' do
        allow(manager).to receive(:decompress)
        allow(task).to receive_messages(output: task_dir)
        expect(File).to receive(:directory?).with(task_dir).and_return(true)
        expect(File).to receive(:file?).with(File.join(task_dir, 'soap')).and_return(false)

        expect(manager.log_file(task, 'soap')).to match(%{/cpi})
      end

      it 'should return the soap log if it exist' do
        allow(manager).to receive(:decompress)
        allow(task).to receive_messages(output: task_dir)
        expect(File).to receive(:directory?).with(task_dir).and_return(true)
        expect(File).to receive(:file?).with(File.join(task_dir, 'soap')).and_return(true)

        expect(manager.log_file(task, 'cpi')).to match(%{/soap})
      end
    end

    it 'should return the task log path' do
      allow(task).to receive_messages(output: task_dir)
      allow(manager).to receive(:decompress)

      expect(File).to receive(:directory?).with(task_dir).and_return(true)
      expect(File).to receive(:file?).with(File.join(task_dir, 'soap')).and_return(false)

      manager.log_file(task, 'cpi')
    end
  end
end
