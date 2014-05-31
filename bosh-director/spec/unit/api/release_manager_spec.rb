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

    describe '#find_version' do
      before do
        @release = BD::Models::Release.make(:name => 'fake-release-name')
        @final_release_version = BD::Models::ReleaseVersion.make(:release => @release, :version => '9')
        @old_dev_release_version = BD::Models::ReleaseVersion.make(:release => @release, :version => '9.1-dev')
        @new_dev_release_version = BD::Models::ReleaseVersion.make(:release => @release, :version => '9+dev.2')
      end

      context 'when version as specified exists in the database' do
        it 'returns the matching version model' do
          expect(subject.find_version(@release, '9')).to eq(@final_release_version)
          expect(subject.find_version(@release, '9.1-dev')).to eq(@old_dev_release_version)
          expect(subject.find_version(@release, '9+dev.2')).to eq(@new_dev_release_version)
        end
      end

      context 'when version as specified does not exist in the database' do
        context 'when an equivalent old-format version exists in the database' do
          it 'returns the matching version model' do
            expect(subject.find_version(@release, '9+dev.1')).to eq(@old_dev_release_version)
          end
        end

        context 'when version as specified is an invalid format' do
          it 'raises an error' do
            expect {
              subject.find_version(@release, '1+2+3')
            }.to raise_error(ReleaseVersionInvalid)
          end
        end

        context 'when formatted version exists in the database' do
          it 'returns the matching version model' do
            expect(subject.find_version(@release, '9.2-dev')).to eq(@new_dev_release_version)
          end
        end

        context 'when formatted version does not exist in the database' do
          it 'raises an error' do
            expect {
              subject.find_version(@release, '9.1')
            }.to raise_error(ReleaseVersionNotFound)

            expect {
              subject.find_version(@release, '9.1.3-dev')
            }.to raise_error(ReleaseVersionNotFound)
          end
        end
      end
    end
  end
end
