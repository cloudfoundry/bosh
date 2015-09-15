require 'spec_helper'
require 'support/release_helper'

module Bosh::Director
  describe Jobs::UpdateRelease do
    before { allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore) }
    let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient') }

    describe 'Resque job class expectations' do
      let(:job_type) { :update_release }
      it_behaves_like 'a Resque job'
    end

    describe 'Compiled release upload' do
      subject(:job) { Jobs::UpdateRelease.new(release_path, job_options) }

      let(:release_dir) { Test::ReleaseHelper.new.create_release_tarball(manifest) }
      let(:release_path) { File.join(release_dir, 'release.tgz') }
      let(:release_version) { '42+dev.6' }
      let(:release) { Models::Release.make(name: 'appcloud') }

      let(:manifest_jobs) do
        [
            {
                'name' => 'fake-job-1',
                'version' => 'fake-version-1',
                'sha1' => 'fake-sha1-1',
                'fingerprint' => 'fake-fingerprint-1',
                'templates' => {}
            },
            {
                'name' => 'fake-job-2',
                'version' => 'fake-version-2',
                'sha1' => 'fake-sha1-2',
                'fingerprint' => 'fake-fingerprint-2',
                'templates' => {}
            }
        ]
      end
      let(:manifest_compiled_packages) do
        [
            {
                'sha1' => 'fake-sha-1',
                'fingerprint' => 'fake-fingerprint-1',
                'name' => 'fake-name-1',
                'version' => 'fake-version-1'
            },
            {
                'sha1' => 'fake-sha-2',
                'fingerprint' => 'fake-fingerprint-2',
                'name' => 'fake-name-2',
                'version' => 'fake-version-2'
            }
        ]
      end
      let(:manifest) do
        {
            'name' => 'appcloud',
            'version' => release_version,
            'jobs' => manifest_jobs,
            'compiled_packages' => manifest_compiled_packages,
        }
      end

      let(:job_options) { {'remote' => false} }

      before do
        allow(Dir).to receive(:mktmpdir).and_return(release_dir)
        allow(job).to receive(:with_release_lock).and_yield
        allow(blobstore).to receive(:create)
        allow(job).to receive(:register_package)
      end

      it 'should process packages for compiled release' do
          expect(job).to receive(:create_packages)
          expect(job).to receive(:use_existing_packages)
          expect(job).to receive(:create_compiled_packages)
          expect(job).to receive(:register_template).twice
          expect(job).to receive(:create_job).twice

          job.perform
        end
    end

    describe '#perform' do
      subject(:job) { Jobs::UpdateRelease.new(release_path, job_options) }
      let(:job_options) { {} }

      let(:release_dir) { Test::ReleaseHelper.new.create_release_tarball(manifest) }
      before { allow(Dir).to receive(:mktmpdir).and_return(release_dir) }

      let(:release_path) { File.join(release_dir, 'release.tgz') }

      let(:manifest) do
        {
          'name' => 'appcloud',
          'version' => release_version,
          'commit_hash' => '12345678',
          'uncommitted_changes' => true,
          'jobs' => manifest_jobs,
          'packages' => manifest_packages,
        }
      end
      let(:release_version) { '42+dev.6' }
      let(:release) { Models::Release.make(name: 'appcloud') }
      let(:manifest_packages) { [] }
      let(:manifest_jobs) { [] }
      before { allow(job).to receive(:with_release_lock).and_yield }

      context 'when release is local' do
        let(:job_options) { {} }

        it 'with a local release' do
          expect(job).not_to receive(:download_remote_release)
          expect(job).to receive(:extract_release)
          expect(job).to receive(:verify_manifest)
          expect(job).to receive(:process_release)
          job.perform
        end
      end

      context 'when release is remote' do
        let(:job_options) { {'remote' => true, 'location' => 'release_location'} }

        it 'with a remote release' do
          expect(job).to receive(:download_remote_release)
          expect(job).to receive(:extract_release)
          expect(job).to receive(:verify_manifest)
          expect(job).to receive(:process_release)

          job.perform
        end
      end

      context 'when commit_hash and uncommitted changes flag are present' do
        let(:manifest) do
          {
            'name' => 'appcloud',
            'version' => '42.6-dev',
            'commit_hash' => '12345678',
            'uncommitted_changes' => 'true',
            'jobs' => [],
            'packages' => [],
          }
        end

        it 'sets commit_hash and uncommitted changes flag on release_version' do
          job.perform

          rv = Models::ReleaseVersion.filter(version: '42+dev.6').first
          expect(rv).not_to be_nil
          expect(rv.commit_hash).to eq('12345678')
          expect(rv.uncommitted_changes).to be(true)
        end
      end

      context 'when commit_hash and uncommitted_changes flag are missing' do
        let(:manifest) do
          {
            'name' => 'appcloud',
            'version' => '42.6-dev',
            'jobs' => [],
            'packages' => []
          }
        end

        it 'sets default commit_hash and uncommitted changes' do
          job.perform

          rv = Models::ReleaseVersion.filter(version: '42+dev.6').first
          expect(rv).not_to be_nil
          expect(rv.commit_hash).to eq('unknown')
          expect(rv.uncommitted_changes).to be(false)
        end
      end

      context 'when extracting release fails' do
        before do
          result = Bosh::Exec::Result.new('cmd', 'output', 1)
          expect(Bosh::Exec).to receive(:sh).and_return(result)
        end

        it 'raises an error' do
          expect {
            job.perform
          }.to raise_exception(Bosh::Director::ReleaseInvalidArchive)
        end

        it 'deletes release archive and the release dir' do
          expect(FileUtils).to receive(:rm_rf).with(release_dir)
          expect(FileUtils).to receive(:rm_rf).with(release_path)

          expect {
            job.perform
          }.to raise_exception(Bosh::Director::ReleaseInvalidArchive)
        end
      end

      it 'saves release version' do
        job.perform

        rv = Models::ReleaseVersion.filter(version: '42+dev.6').first
        expect(rv).to_not be_nil
      end

      it 'resolves package dependencies' do
        expect(job).to receive(:resolve_package_dependencies)
        job.perform
      end

      it 'deletes release archive and extraction directory' do
        expect(FileUtils).to receive(:rm_rf).with(release_dir)
        expect(FileUtils).to receive(:rm_rf).with(release_path)

        job.perform
      end

      context 'release already exists' do
        before { Models::ReleaseVersion.make(release: release, version: '42+dev.6', commit_hash: '12345678', uncommitted_changes: true) }

        context 'when rebase is passed' do
          let(:job_options) { { 'rebase' => true } }

          context 'when there are package changes' do
            let(:manifest_packages) do
              [
                {
                  'sha1' => 'fake-sha-1',
                  'fingerprint' => 'fake-fingerprint-1',
                  'name' => 'fake-name-1',
                  'version' => 'fake-version-1'
                }
              ]
            end

            it 'sets a next release version' do
              expect(job).to receive(:create_package)
              expect(job).to receive(:register_package)
              job.perform

              rv = Models::ReleaseVersion.filter(version: '42+dev.7').first
              expect(rv).to_not be_nil
            end
          end

          context 'when there are no job and package changes' do
            it 'still can pass and set a next release version' do
              # it just generate the next release version without creating/registering package
              expect {
                job.perform
              }.to_not raise_error

              rv = Models::ReleaseVersion.filter(version: '42+dev.7').first
              expect(rv).to_not be_nil
            end
          end
        end

        context 'when skip_if_exists is passed' do
          let(:job_options) { { 'skip_if_exists' => true } }

          it 'does not create a release' do
            expect(job).not_to receive(:create_package)
            expect(job).not_to receive(:create_job)
            job.perform
          end
        end
      end

      context 'when the same release is uploaded with different commit hash' do
        before { Models::ReleaseVersion.make(release: release, version: '42+dev.6', commit_hash: 'bad123', uncommitted_changes: true) }

        it 'fails with a ReleaseVersionCommitHashMismatch exception' do
          expect {
            job.perform
          }.to raise_exception(Bosh::Director::ReleaseVersionCommitHashMismatch)
        end
      end

      context 'when the release version does not match database valid format' do
        before do
          # We only want to verify that the proper error is raised
          # If version can not be validated because it has wrong model format
          # Currently SemiSemantic Version validates version that matches the model format
          stub_const("Bosh::Director::Models::VALID_ID", /^[a-z0-9]+$/i)
        end

        let(:release_version) { 'bad-version' }

        it 'raises an error ReleaseVersionInvalid' do
          expect {
            job.perform
          }.to raise_error(Sequel::ValidationFailed)
        end
      end

      context 'when there are packages in manifest' do
        let(:manifest_packages) do
          [
            {
              'sha1' => 'fake-sha-1',
              'fingerprint' => 'fake-fingerprint-1',
              'name' => 'fake-name-1',
              'version' => 'fake-version-1'
            },
            {
              'sha1' => 'fake-sha-2',
              'fingerprint' => 'fake-fingerprint-2',
              'name' => 'fake-name-2',
              'version' => 'fake-version-2'
            }
          ]
        end

        before do
          Models::Package.make(release: release, name: 'fake-name-1', version: 'fake-version-1', fingerprint: 'fake-fingerprint-1')
        end

        it "creates packages that don't already exist" do
          expect(job).to receive(:create_packages).with([
            {
              'sha1' => 'fake-sha-2',
              'fingerprint' => 'fake-fingerprint-2',
              'name' => 'fake-name-2',
              'version' => 'fake-version-2',
              'dependencies' => []
            }
          ], release_dir)
          job.perform
        end

        it 'raises an error if a different fingerprint was detected for an already existing package' do
          pkg = Models::Package.make(release: release, name: 'fake-name-2', version: 'fake-version-2', fingerprint: 'different-finger-print', sha1: 'fake-sha-2')
          release_version = Models::ReleaseVersion.make(release: release, version: '42+dev.6', commit_hash: '12345678', uncommitted_changes: true)
          release_version.add_package(pkg)

          allow(job).to receive(:create_packages)

          expect {
            job.perform
          }.to raise_exception(Bosh::Director::ReleaseInvalidPackage, /package `fake-name-2' had different fingerprint in previously uploaded release `appcloud\/42\+dev.6'/)
        end
      end

      describe 'event_log' do
        it 'prints that release was created' do
          allow(Config.event_log).to receive(:begin_stage).and_call_original
          expect(Config.event_log).to receive(:begin_stage).with('Release has been created', 1)
          job.perform
        end

        it 'prints name and version' do
          allow(Config.event_log).to receive(:track).and_call_original
          expect(Config.event_log).to receive(:track).with('appcloud/42+dev.6')
          job.perform
        end
      end

      context 'when manifest contains jobs' do
        let(:manifest_jobs) do
          [
            {
              'name' => 'fake-job-1',
              'version' => 'fake-version-1',
              'sha1' => 'fake-sha1-1',
              'fingerprint' => 'fake-fingerprint-1',
              'templates' => {}
            },
            {
              'name' => 'fake-job-2',
              'version' => 'fake-version-2',
              'sha1' => 'fake-sha1-2',
              'fingerprint' => 'fake-fingerprint-2',
              'templates' => {}
            }
          ]
        end

        it 'creates job' do
          expect(blobstore).to receive(:create) do |file|
            expect(file.path).to eq(File.join(release_dir, 'jobs', 'fake-job-1.tgz'))
          end

          expect(blobstore).to receive(:create) do |file|
            expect(file.path).to eq(File.join(release_dir, 'jobs', 'fake-job-2.tgz'))
          end

          job.perform

          expect(Models::Template.all.size).to eq(2)
          expect(Models::Template.all.map(&:name)).to match_array(['fake-job-1', 'fake-job-2'])
        end

        it 'raises an error if a different fingerprint was detected for an already existing job' do
          corrupted_job = Models::Template.make(release: release, name: 'fake-job-1', version: 'fake-version-1', fingerprint: 'different-finger-print', sha1: 'fake-sha1-1')
          release_version = Models::ReleaseVersion.make(release: release, version: '42+dev.6', commit_hash: '12345678', uncommitted_changes: true)
          release_version.add_template(corrupted_job)

          allow(job).to receive(:process_packages)

          expect {
            job.perform
          }.to raise_exception(Bosh::Director::ReleaseExistingJobFingerprintMismatch, /job `fake-job-1' had different fingerprint in previously uploaded release `appcloud\/42\+dev.6'/)
        end

        it "creates jobs that don't already exist" do
          Models::Template.make(
              release: release,
              name: 'fake-job-1',
              version: 'fake-version-1',
              fingerprint: 'fake-fingerprint-1'
          )
          expect(job).to receive(:create_jobs).with([
              {
                  'sha1' => 'fake-sha1-2',
                  'fingerprint' => 'fake-fingerprint-2',
                  'name' => 'fake-job-2',
                  'version' => 'fake-version-2',
                  'templates' => {}
              }
          ], release_dir)
          job.perform
        end
      end

      context 'when manifest contains packages and jobs' do
        let(:manifest_jobs) do [
            {
                'name' => 'zbz',
                'version' => '666',
                'templates' => {},
                'packages' => %w(zbb),
                'fingerprint' => 'job-fingerprint-3'
            }
        ]
        end
        let(:manifest_packages) do [
            {
                'name' => 'foo',
                'version' => '2.33-dev',
                'dependencies' => %w(bar),
                'fingerprint' => 'package-fingerprint-1',
                'sha1' => 'package-sha1-1'
            },
            {
                'name' => 'bar',
                'version' => '3.14-dev',
                'dependencies' => [],
                'fingerprint' => 'package-fingerprint-2',
                'sha1' => 'package-sha1-2'
            },
            {
                'name' => 'zbb',
                'version' => '333',
                'dependencies' => [],
                'fingerprint' => 'package-fingerprint-3',
                'sha1' => 'package-sha1-3'
            }
        ]
        end

        it 'process packages should include all packages from the manifest in the packages array, even previously existing ones' do
          pkg_foo = Models::Package.make(release: release, name: 'foo', version: '2.33-dev', fingerprint: 'package-fingerprint-1', sha1: 'package-sha1-1', blobstore_id: 'bs1')
          pkg_bar = Models::Package.make(release: release, name: 'bar', version: '3.14-dev', fingerprint: 'package-fingerprint-2', sha1: 'package-sha1-2', blobstore_id: 'bs2')
          pkg_zbb = Models::Package.make(release: release, name: 'zbb', version: '333', fingerprint: 'package-fingerprint-3', sha1: 'package-sha1-3', blobstore_id: 'bs3')
          release_version = Models::ReleaseVersion.make(release: release, version: '42+dev.6', commit_hash: '12345678', uncommitted_changes: true)
          release_version.add_package(pkg_foo)
          release_version.add_package(pkg_bar)
          release_version.add_package(pkg_zbb)

          expect(BlobUtil).to receive(:create_blob).and_return('blob_id')
          allow(blobstore).to receive(:create)

          job.perform
        end
      end
    end

    describe 'rebasing release' do
      let(:manifest) do
        {
          'name' => 'appcloud',
          'version' => '42.6-dev',
          'jobs' => [
            {
              'name' => 'baz',
              'version' => '33',
              'templates' => {
                'bin/test.erb' => 'bin/test',
                'config/zb.yml.erb' => 'config/zb.yml'
              },
              'packages' => %w(foo bar),
              'fingerprint' => 'job-fingerprint-1'
            },
            {
              'name' => 'zaz',
              'version' => '0.2-dev',
              'templates' => {},
              'packages' => %w(bar),
              'fingerprint' => 'job-fingerprint-2'
            },
            {
              'name' => 'zbz',
              'version' => '666',
              'templates' => {},
              'packages' => %w(zbb),
              'fingerprint' => 'job-fingerprint-3'
            }
          ],
          'packages' => [
            {
              'name' => 'foo',
              'version' => '2.33-dev',
              'dependencies' => %w(bar),
              'fingerprint' => 'package-fingerprint-1',
              'sha1' => 'package-sha1-1'
            },
            {
              'name' => 'bar',
              'version' => '3.14-dev',
              'dependencies' => [],
              'fingerprint' => 'package-fingerprint-2',
              'sha1' => 'package-sha1-2'
            },
            {
              'name' => 'zbb',
              'version' => '333',
              'dependencies' => [],
              'fingerprint' => 'package-fingerprint-3',
              'sha1' => 'package-sha1-3'
            }
          ]
        }
      end

      before do
        @release_dir = Test::ReleaseHelper.new.create_release_tarball(manifest)
        @release_path = File.join(@release_dir, 'release.tgz')

        @job = Jobs::UpdateRelease.new(@release_path, 'rebase' => true)

        @release = Models::Release.make(name: 'appcloud')
        @rv = Models::ReleaseVersion.make(release: @release, version: '37')

        Models::Package.make(release: @release, name: 'foo', version: '2.7-dev')
        Models::Package.make(release: @release, name: 'bar', version: '42')

        Models::Template.make(release: @release, name: 'baz', version: '33.7-dev')
        Models::Template.make(release: @release, name: 'zaz', version: '17')

        # create up to 6 new blobs (3*job + 3*package)
        allow(blobstore).to receive(:create).at_most(6).and_return('b1', 'b2', 'b3', 'b4', 'b5', 'b6')
        # get is only called when a blob is copied
        allow(blobstore).to receive(:get)
        allow(@job).to receive(:with_release_lock).with('appcloud').and_yield
      end

      it 'rebases the release version' do
        @job.perform

        # No previous release exists with the same release version (42).
        # So the default dev post-release version is used (semi-semantic format).
        rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first

        expect(rv).to_not be_nil
      end

      context 'when the package fingerprint matches one in the database' do
        before do
          Models::Package.make(
            release: @release,
            name: 'zbb',
            version: '25',
            fingerprint: 'package-fingerprint-3',
            sha1: 'package-sha1-old',
          )
        end

        it 'creates new package (version) with copied blob (sha1)' do
          expect(blobstore).to receive(:create).exactly(6).times # creates new blobs for each package & job
          expect(blobstore).to receive(:get).exactly(1).times # copies the existing 'zbb' package
          @job.perform

          zbbs = Models::Package.filter(release_id: @release.id, name: 'zbb').all
          expect(zbbs.map(&:version)).to match_array(%w(25 333))

          # Fingerprints are the same because package contents did not change
          expect(zbbs.map(&:fingerprint)).to match_array(%w(package-fingerprint-3 package-fingerprint-3))

          # SHA1s are the same because first blob was copied
          expect(zbbs.map(&:sha1)).to match_array(%w(package-sha1-old package-sha1-old))
        end

        it 'associates newly created packages to the release version' do
          @job.perform

          rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first
          expect(rv.packages.map(&:version)).to match_array(%w(2.33-dev 3.14-dev 333))
          expect(rv.packages.map(&:fingerprint)).to match_array(%w(package-fingerprint-1 package-fingerprint-2 package-fingerprint-3))
          expect(rv.packages.map(&:sha1)).to match_array(%w(package-sha1-1 package-sha1-2 package-sha1-old))
        end
      end

      context 'when the package fingerprint matches multiple in the database' do
        before do
          Models::Package.make(release: @release, name: 'zbb', version: '25', fingerprint: 'package-fingerprint-3', sha1: 'package-sha1-25')
          Models::Package.make(release: @release, name: 'zbb', version: '26', fingerprint: 'package-fingerprint-3', sha1: 'package-sha1-26')
        end

        it 'creates new package (version) with copied blob (sha1)' do
          expect(blobstore).to receive(:create).exactly(6).times # creates new blobs for each package & job
          expect(blobstore).to receive(:get).exactly(1).times # copies the existing 'zbb' package
          @job.perform

          zbbs = Models::Package.filter(release_id: @release.id, name: 'zbb').all
          expect(zbbs.map(&:version)).to match_array(%w(26 25 333))

          # Fingerprints are the same because package contents did not change
          expect(zbbs.map(&:fingerprint)).to match_array(%w(package-fingerprint-3 package-fingerprint-3 package-fingerprint-3))

          # SHA1s are the same because first blob was copied
          expect(zbbs.map(&:sha1)).to match_array(%w(package-sha1-25 package-sha1-25 package-sha1-26))
        end

        it 'associates newly created packages to the release version' do
          @job.perform

          rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first
          expect(rv.packages.map(&:version)).to match_array(%w(2.33-dev 3.14-dev 333))
          expect(rv.packages.map(&:fingerprint)).to match_array(%w(package-fingerprint-1 package-fingerprint-2 package-fingerprint-3))
          expect(rv.packages.map(&:sha1)).to match_array(%w(package-sha1-1 package-sha1-2 package-sha1-25))
        end
      end

      context 'when the package fingerprint is new' do
        before do
          Models::Package.make(release: @release, name: 'zbb', version: '25', fingerprint: 'package-fingerprint-old', sha1: 'package-sha1-25')
        end

        it 'creates new package (version) with new blob (sha1)' do
          expect(blobstore).to receive(:create).exactly(6).times # creates new blobs for each package & job
          expect(blobstore).to receive(:get).exactly(0).times # does not copy any existing packages or jobs
          @job.perform

          zbbs = Models::Package.filter(release_id: @release.id, name: 'zbb').all
          expect(zbbs.map(&:version)).to match_array(%w(25 333))

          # Fingerprints are different because package contents are different
          expect(zbbs.map(&:fingerprint)).to match_array(%w(package-fingerprint-old package-fingerprint-3))

          # SHA1s are different because package tars are different
          expect(zbbs.map(&:sha1)).to match_array(%w(package-sha1-25 package-sha1-3))
        end

        it 'associates newly created packages to the release version' do
          @job.perform

          rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first
          expect(rv.packages.map(&:version)).to match_array(%w(2.33-dev 3.14-dev 333))
          expect(rv.packages.map(&:fingerprint)).to match_array(%w(package-fingerprint-1 package-fingerprint-2 package-fingerprint-3))
          expect(rv.packages.map(&:sha1)).to match_array(%w(package-sha1-1 package-sha1-2 package-sha1-3))
        end
      end

      context 'when the job fingerprint matches one in the database' do
        before do
          Models::Template.make(release: @release, name: 'zbz', version: '28', fingerprint: 'job-fingerprint-3')
        end

        it 'uses the new job blob' do
          expect(blobstore).to receive(:create).exactly(6).times # creates new blobs for each package & job
          expect(blobstore).to receive(:get).exactly(0).times # does not copy any existing packages or jobs
          @job.perform

          zbzs = Models::Template.filter(release_id: @release.id, name: 'zbz').all
          expect(zbzs.map(&:version)).to match_array(%w(28 666))
          expect(zbzs.map(&:fingerprint)).to match_array(%w(job-fingerprint-3 job-fingerprint-3))

          rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first
          expect(rv.templates.map(&:fingerprint)).to match_array(%w(job-fingerprint-1 job-fingerprint-2 job-fingerprint-3))
        end
      end

      context 'when the job fingerprint is new' do
        before do
          Models::Template.make(release: @release, name: 'zbz', version: '28', fingerprint: 'job-fingerprint-old')
        end

        it 'uses the new job blob' do
          expect(blobstore).to receive(:create).exactly(6).times # creates new blobs for each package & job
          expect(blobstore).to receive(:get).exactly(0).times # does not copy any existing packages or jobs
          @job.perform

          zbzs = Models::Template.filter(release_id: @release.id, name: 'zbz').all
          expect(zbzs.map(&:version)).to match_array(%w(28 666))
          expect(zbzs.map(&:fingerprint)).to match_array(%w(job-fingerprint-old job-fingerprint-3))

          rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first
          expect(rv.templates.map(&:fingerprint)).to match_array(%w(job-fingerprint-1 job-fingerprint-2 job-fingerprint-3))
        end
      end

      it 'uses major+dev.1 version for initial rebase if no version exists' do
        @rv.destroy
        Models::Package.each { |p| p.destroy }
        Models::Template.each { |t| t.destroy }

        @job.perform

        foos = Models::Package.filter(release_id: @release.id, name: 'foo').all
        bars = Models::Package.filter(release_id: @release.id, name: 'bar').all

        expect(foos.map { |foo| foo.version }).to match_array(%w(2.33-dev))
        expect(bars.map { |bar| bar.version }).to match_array(%w(3.14-dev))

        bazs = Models::Template.filter(release_id: @release.id, name: 'baz').all
        zazs = Models::Template.filter(release_id: @release.id, name: 'zaz').all

        expect(bazs.map { |baz| baz.version }).to match_array(%w(33))
        expect(zazs.map { |zaz| zaz.version }).to match_array(%w(0.2-dev))

        rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first

        expect(rv.packages.map { |p| p.version }).to match_array(%w(2.33-dev 3.14-dev 333))
        expect(rv.templates.map { |t| t.version }).to match_array(%w(0.2-dev 33 666))
      end

      it 'performs the rebase if same release is being rebased twice' do
        Config.configure(Psych.load(spec_asset('test-director-config.yml')))
        @job.perform

        @release_dir = Test::ReleaseHelper.new.create_release_tarball(manifest)
        @release_path = File.join(@release_dir, 'release.tgz')
        @job = Jobs::UpdateRelease.new(@release_path, 'rebase' => true)

        expect {
          @job.perform
        }.to_not raise_error

        rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.2').first
        expect(rv).to_not be_nil
      end
    end

    describe 'create_package_for_compiled_release' do
      let(:release_dir) { Dir.mktmpdir }
      after { FileUtils.rm_rf(release_dir) }

      before do
        @release = Models::Release.make
        @job = Jobs::UpdateRelease.new(release_dir)
        @job.release_model = @release
        @job.instance_variable_set(:@compiled_release, true)
      end

      it 'should create simple packages without blobstore_id or sha1' do
        @job.create_package({
                                'name' => 'test_package',
                                'version' => '1.0',
                                'sha1' => nil,
                                'dependencies' => %w(foo_package bar_package)
                            }, release_dir)

        package = Models::Package[name: 'test_package', version: '1.0']
        expect(package).not_to be_nil
        expect(package.name).to eq('test_package')
        expect(package.version).to eq('1.0')
        expect(package.release).to eq(@release)
        expect(package.sha1).to be_nil
        expect(package.blobstore_id).to be_nil
      end
    end

    describe 'create_package' do
      let(:release_dir) { Dir.mktmpdir }
      after { FileUtils.rm_rf(release_dir) }

      before do
        @release = Models::Release.make
        @job = Jobs::UpdateRelease.new(release_dir)
        @job.release_model = @release
      end

      it 'should create simple packages' do
        FileUtils.mkdir_p(File.join(release_dir, 'packages'))
        package_path = File.join(release_dir, 'packages', 'test_package.tgz')

        File.open(package_path, 'w') do |f|
          f.write(create_package('test' => 'test contents'))
        end

        expect(blobstore).to receive(:create).
          with(satisfy { |obj| obj.path == package_path }).
          and_return('blob_id')

        @job.create_package({
          'name' => 'test_package',
          'version' => '1.0',
          'sha1' => 'some-sha',
          'dependencies' => %w(foo_package bar_package)
        }, release_dir)

        package = Models::Package[name: 'test_package', version: '1.0']
        expect(package).not_to be_nil
        expect(package.name).to eq('test_package')
        expect(package.version).to eq('1.0')
        expect(package.release).to eq(@release)
        expect(package.sha1).to eq('some-sha')
        expect(package.blobstore_id).to eq('blob_id')
      end

      it 'should copy package blob' do
        expect(BlobUtil).to receive(:copy_blob).and_return('blob_id')
        FileUtils.mkdir_p(File.join(release_dir, 'packages'))
        package_path = File.join(release_dir, 'packages', 'test_package.tgz')
        File.open(package_path, 'w') do |f|
          f.write(create_package('test' => 'test contents'))
        end

        @job.create_package({
          'name' => 'test_package',
          'version' => '1.0', 'sha1' => 'some-sha',
          'dependencies' => ['foo_package', 'bar_package'],
          'blobstore_id' => 'blah',
        }, release_dir)

        package = Models::Package[name: 'test_package', version: '1.0']
        expect(package).not_to be_nil
        expect(package.name).to eq('test_package')
        expect(package.version).to eq('1.0')
        expect(package.release).to eq(@release)
        expect(package.sha1).to eq('some-sha')
        expect(package.blobstore_id).to eq('blob_id')
      end

      it 'should fail if cannot extract package archive' do
        result = Bosh::Exec::Result.new('cmd', 'output', 1)
        expect(Bosh::Exec).to receive(:sh).and_return(result)

        expect {
          @job.create_package({
            'name' => 'test_package',
            'version' => '1.0',
            'sha1' => 'some-sha',
            'dependencies' => %w(foo_package bar_package),
          }, release_dir)
        }.to raise_exception(Bosh::Director::PackageInvalidArchive)
      end

      def create_package(files)
        io = StringIO.new

        Archive::Tar::Minitar::Writer.open(io) do |tar|
          files.each do |key, value|
            tar.add_file(key, {:mode => "0644", :mtime => 0}) { |os, _| os.write(value) }
          end
        end

        io.close
        gzip(io.string)
      end
    end

    describe 'resolve_package_dependencies' do
      before do
        @job = Jobs::UpdateRelease.new('fake-release-path')
      end

      it 'should normalize nil dependencies' do
        packages = [
          {'name' => 'A'},
          {'name' => 'B', 'dependencies' => ['A']}
        ]
        @job.resolve_package_dependencies(packages)
        expect(packages).to eql([
          {'name' => 'A', 'dependencies' => []},
          {'name' => 'B', 'dependencies' => ['A']}
        ])
      end

      it 'should not allow cycles' do
        packages = [
          {'name' => 'A', 'dependencies' => ['B']},
          {'name' => 'B', 'dependencies' => ['A']}
        ]
        expect { @job.resolve_package_dependencies(packages) }.to raise_exception
      end
    end
  end
end
