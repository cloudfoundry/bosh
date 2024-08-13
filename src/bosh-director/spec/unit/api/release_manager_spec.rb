require 'spec_helper'

module Bosh::Director
  describe Api::ReleaseManager do
    let(:task) { double('Task') }
    let(:username) { 'username-1' }
    let(:options) do
      { foo: 'bar' }
    end

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

    describe '#get_all_releases' do
      it 'gets all releases' do
        release_1 = Models::Release.make(name: 'release-a')
        release_2 = Models::Release.make(name: 'release-b')
        deployment_1 = Models::Deployment.make
        template_1 = Models::Template.make(name: 'job-1', release: release_1)
        template_2 = Models::Template.make(name: 'job-2', release: release_2)
        version_1 = Models::ReleaseVersion.make(version: 1, release: release_1)
        version_1.add_template(template_1)
        version_1.add_deployment(deployment_1)
        version_2 = Models::ReleaseVersion.make(version: 2, release: release_2)
        version_2.add_template(template_2)

        releases = subject.get_all_releases

        expect(releases).to eq([{
                'name' => 'release-a',
                'release_versions' => [{
                    'version' => '1',
                    'commit_hash' => version_1.commit_hash,
                    'uncommitted_changes' => version_1.uncommitted_changes,
                    'currently_deployed' => true,
                    'job_names' => ['job-1']
                  }]
              },
              'name' => 'release-b',
              'release_versions' => [{
                  'version' => '2',
                  'commit_hash' => version_2.commit_hash,
                  'uncommitted_changes' => version_2.uncommitted_changes,
                  'currently_deployed' => false,
                  'job_names' => ['job-2'],
                }]
            ])
      end

      it 'orders releases in ascending order of release name' do
        Models::Release.make(name: 'b')
        Models::Release.make(name: '1c')
        Models::Release.make(name: 'a')

        releases = subject.get_all_releases

        release_names = releases.map{ |release| release['name'] }
        expect(release_names).to eq(['1c', 'a', 'b'])
      end

      it 'orders releases in ascending order of release version' do
        release = Models::Release.make(name: 'a')
        Models::ReleaseVersion.make(version: 3, release: release)
        Models::ReleaseVersion.make(version: 10, release: release)
        Models::ReleaseVersion.make(version: 1, release: release)

        releases = subject.get_all_releases

        release_versions = releases.first['release_versions']
        release_version_numbers = release_versions.map{ |release_version| release_version['version'] }
        expect(release_version_numbers).to eq(['1', '3', '10'])
      end
    end

    describe '#sorted_release_version' do
      let(:release) { Models::Release.make(name: 'release-a') }

      before do
        Models::ReleaseVersion.make(version: '1', release: release)
        Models::ReleaseVersion.make(version: '2.1', release: release)
        Models::ReleaseVersion.make(version: '2.2', release: release)
        Models::ReleaseVersion.make(version: '2.3', release: release)
      end

      it 'returns a transformed array' do
        sorted_release_versions = subject.sorted_release_versions(release)

        expect(sorted_release_versions[0]['version']).to eq('1')
        expect(sorted_release_versions[1]['version']).to eq('2.1')
        expect(sorted_release_versions[2]['version']).to eq('2.2')
        expect(sorted_release_versions[3]['version']).to eq('2.3')
      end

      context 'when filtering by version prefix' do
        it 'returns a limited version list' do
          sorted_release_versions = subject.sorted_release_versions(release, '2')

          expect(sorted_release_versions[0]['version']).to eq('2.1')
          expect(sorted_release_versions[1]['version']).to eq('2.2')
          expect(sorted_release_versions[2]['version']).to eq('2.3')
        end

        it 'returns a limited version list' do
          sorted_release_versions = subject.sorted_release_versions(release, '2.2')

          expect(sorted_release_versions[0]['version']).to eq('2.2')
        end

        context 'using a non-existant prefix' do
          it 'returns an empty list' do
            sorted_release_versions = subject.sorted_release_versions(release, '3')

            expect(sorted_release_versions).to eq([])
          end
        end
      end
    end

    describe '#create_release_from_file_path' do
      let(:release_path) { '/path/to/release.tgz' }

      context 'when release file exists' do
        before { allow(File).to receive(:exist?).with(release_path).and_return(true) }

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
        before { allow(File).to receive(:exist?).with(release_path).and_return(false) }

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

      it 'enqueues a DJ job' do
        expect(job_queue).to receive(:enqueue).with(
          username, Jobs::DeleteRelease, "delete release: #{release.name}", [release.name, options]).and_return(task)

        expect(subject.delete_release(username, release, options)).to eq(task)
      end
    end

    describe '#find_version' do
      before do
        @release = Bosh::Director::Models::Release.make(:name => 'fake-release-name')
        @final_release_version = Bosh::Director::Models::ReleaseVersion.make(:release => @release, :version => '9')
        @old_dev_release_version = Bosh::Director::Models::ReleaseVersion.make(:release => @release, :version => '9.1-dev')
        @new_dev_release_version = Bosh::Director::Models::ReleaseVersion.make(:release => @release, :version => '9+dev.2')
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
