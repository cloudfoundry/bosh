require 'spec_helper'

describe Bosh::Director::Api::ReleaseManager do
  let(:task) { double('Task', id: 42) }
  let(:user) { 'FAKE_USER' }

  before do
    Resque.stub(:enqueue)
    BD::JobQueue.any_instance.stub(create_task: task)
  end

  pending '#find_by_name'

  pending '#find_by_version'

  describe '#create_release' do
    context 'when sufficient disk space is available' do
      before do
        subject.stub(check_available_disk_space: true)
        subject.stub(:write_file)
      end

      it 'returns the task created by JobQueue' do
        expect(subject.create_release(user, 'FAKE_RELEASE_BUNDLE')).to eq(task)
      end

      context 'local release' do
        it 'enqueues a resque job' do
          Dir.stub(mktmpdir: 'FAKE_TMPDIR')

          Resque.should_receive(:enqueue).with(BD::Jobs::UpdateRelease, task.id, 'FAKE_TMPDIR', {})

          subject.create_release(user, 'FAKE_RELEASE_BUNDLE')
        end
      end

      context 'remote release' do
        it 'enqueues a resque job' do
          Dir.stub(mktmpdir: 'FAKE_TMPDIR')

          Resque.should_receive(:enqueue)
            .with(BD::Jobs::UpdateRelease, task.id, 'FAKE_TMPDIR', {'remote' => true,
                                                                    'location' => 'FAKE_RELEASE_BUNDLE'})

          subject.create_release(user, 'FAKE_RELEASE_BUNDLE', {'remote' => true})
        end
      end
    end
  end

  describe '#delete_release' do
    let(:release) { double('Release', name: 'FAKE RELEASE') }

    it 'enqueues a resque job' do
      Resque.should_receive(:enqueue).with(BD::Jobs::DeleteRelease, task.id, release.name, {})

      subject.delete_release(user, release)
    end

    it 'returns the task created by JobQueue' do
      expect(subject.delete_release(user, release)).to eq(task)
    end
  end
end