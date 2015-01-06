require 'spec_helper'

module Bosh::Director
  describe Api::ReleaseManager do
    let(:task) { double('Task') }
    let(:username) { 'username-1' }
    let(:options) { { foo: 'bar' } }

    before { allow(Dir).to receive(:mktmpdir).with('release').and_return(tmp_release_dir) }
    let(:tmp_release_dir) { 'fake-tmp-release-dir' }

    before { allow(JobQueue).to receive(:new).and_return(job_queue) }
    let(:job_queue) { instance_double('Bosh::Director::JobQueue') }

    describe '#create_release_from_url' do
      let(:release_url) { 'http://fake-domain.com/release.tgz' }

      it 'enqueues a task to upload a remote release' do
        rebase = double('bool')
        skip_if_exists = double('bool')

        expect(job_queue).to receive(:enqueue).with(
          username,
          Jobs::UpdateRelease,
          'create release',
          [release_url, { remote: true, rebase: rebase, skip_if_exists: skip_if_exists }],
        ).and_return(task)

        expect(
          subject.create_release_from_url(username, release_url, rebase: rebase, skip_if_exists: skip_if_exists),
        ).to eql(task)
      end
    end

    describe '#create_release_from_file_path' do
      let(:release_path) { '/path/to/release.tgz' }

      context 'when release file exists' do
        before { allow(File).to receive(:exists?).with(release_path).and_return(true) }

        it 'enqueues a task to upload a release file' do
          rebase = double('bool')

          expect(job_queue).to receive(:enqueue).with(
            username,
            Jobs::UpdateRelease,
            'create release',
            [release_path, { rebase: rebase }],
          ).and_return(task)

          expect(subject.create_release_from_file_path(username, release_path, rebase: rebase)).to eql(task)
        end
      end

      context 'when release file does not exist' do
        before { allow(File).to receive(:exists?).with(release_path).and_return(false) }

        it 'raises an error' do
          rebase = double('bool')

          expect(job_queue).to_not receive(:enqueue)

          expect {
            expect(subject.create_release_from_file_path(username, release_path, rebase))
          }.to raise_error(DirectorError, /Failed to create release: file not found/)
        end
      end
    end

    describe '#delete_release' do
      let(:release) { double('Release', name: 'FAKE RELEASE') }

      it 'enqueues a resque job' do
        expect(job_queue).to receive(:enqueue).with(
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
