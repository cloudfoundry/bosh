require 'spec_helper'

module Bosh::Director
  describe Api::ReleaseManager do
    let(:task) { double('Task') }
    let(:username) { 'username-1' }
    let(:job_queue) { instance_double('Bosh::Director::JobQueue') }
    let(:options) { { foo: 'bar' } }

    before do
      JobQueue.stub(:new).and_return(job_queue)
      Dir.stub(mktmpdir: 'FAKE_TMPDIR')
    end

    describe '#create_release' do
      context 'when sufficient disk space is available' do
        before do
          subject.stub(check_available_disk_space: true)
          subject.stub(:write_file)
        end

        context 'local release' do
          it 'enqueues a resque job' do
            job_queue.should_receive(:enqueue).with(
              username, Jobs::UpdateRelease, 'create release', ['FAKE_TMPDIR', options]).and_return(task)

            expect(subject.create_release(username, 'FAKE_RELEASE_BUNDLE', options)).to eq(task)
          end
        end

        context 'remote release' do
          let(:options) { { 'remote' => true } }

          it 'enqueues a resque job' do
            modified_options = options.merge({ 'location' => 'FAKE_RELEASE_BUNDLE' })

            job_queue.should_receive(:enqueue).with(
              username, Jobs::UpdateRelease, 'create release', ['FAKE_TMPDIR', modified_options]).and_return(task)

            expect(subject.create_release(username, 'FAKE_RELEASE_BUNDLE', options)).to eq(task)
          end
        end
      end
    end

    describe '#delete_release' do
      let(:release) { double('Release', name: 'FAKE RELEASE') }

      it 'enqueues a resque job' do
        job_queue.should_receive(:enqueue).with(
          username, Jobs::DeleteRelease, "delete release: #{release.name}", [release.name, options]).and_return(task)

        expect(subject.delete_release(username, release, options)).to eq(task)
      end
    end
  end
end
