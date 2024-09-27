require 'spec_helper'
require 'support/release_helper'
require 'digest'

module Bosh::Director
  describe Jobs::UpdateRelease do
    before do
      allow(Bosh::Director::Config).to receive(:verify_multidigest_path).and_return('some/path')
      allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
    end
    let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient', create: true) }
    let(:task) { FactoryBot.create(:models_task, id: 42) }
    let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, task.id) }
    let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }

    before do
      allow(Config).to receive(:event_log).and_return(event_log)
    end

    describe 'DJ job class expectations' do
      let(:job_type) { :update_release }
      let(:queue) { :normal }
      it_behaves_like 'a DJ job'
    end

    describe 'Compiled release upload' do
      subject(:job) { Jobs::UpdateRelease.new(release_path, job_options) }

      let(:release_dir) { Test::ReleaseHelper.new.create_release_tarball(manifest) }
      let(:release_path) { File.join(release_dir, 'release.tgz') }
      let(:release_version) { '42+dev.6' }
      let(:release) { FactoryBot.create(:models_release, name: 'appcloud') }

      let(:manifest_jobs) do
        [
          {
            'name' => 'fake-job-1',
            'version' => 'fake-version-1',
            'sha1' => 'fakesha11',
            'fingerprint' => 'fake-fingerprint-1',
            'templates' => {},
          },
          {
            'name' => 'fake-job-2',
            'version' => 'fake-version-2',
            'sha1' => 'fake-sha1-2',
            'fingerprint' => 'fake-fingerprint-2',
            'templates' => {},
          },
        ]
      end
      let(:manifest_compiled_packages) do
        [
          {
            'sha1' => 'fakesha1',
            'fingerprint' => 'fake-fingerprint-1',
            'name' => 'fake-name-1',
            'version' => 'fake-version-1',
          },
          {
            'sha1' => 'fakesha2',
            'fingerprint' => 'fake-fingerprint-2',
            'name' => 'fake-name-2',
            'version' => 'fake-version-2',
          },
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

      let(:job_options) do
        { 'remote' => false }
      end

      before do
        allow(Dir).to receive(:mktmpdir).and_return(release_dir)
        allow(job).to receive(:with_release_lock).and_yield
        allow(blobstore).to receive(:create)
        allow(Jobs::UpdateRelease::PackagePersister).to receive(:persist)
      end

      it 'should process packages for compiled release' do
        expect(job).to receive(:register_template).twice
        expect(job).to receive(:create_job).twice

        job.perform
      end
    end

    describe '#perform' do
      subject(:job) { Jobs::UpdateRelease.new(release_path, job_options) }
      let(:job_options) do
        {}
      end

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
      let(:release) { FactoryBot.create(:models_release, name: 'appcloud') }
      let(:manifest_packages) { nil }
      let(:manifest_jobs) { nil }
      let(:status) { instance_double(Process::Status, exitstatus: 0) }

      before do
        allow(Open3).to receive(:capture3).and_return([nil, 'some error', status])
        allow(job).to receive(:with_release_lock).and_yield
      end

      context 'when release is local' do
        let(:job_options) do
          {}
        end

        it 'with a local release' do
          expect(job).not_to receive(:download_remote_release)
          expect(job).to receive(:extract_release)
          expect(job).to receive(:verify_manifest)
          expect(job).to receive(:process_release)
          job.perform
        end
      end

      context 'when release is remote' do
        let(:job_options) do
          { 'remote' => true, 'location' => 'release_location' }
        end

        it 'with a remote release' do
          expect(job).to receive(:download_remote_release)
          expect(job).to receive(:extract_release)
          expect(job).to receive(:verify_manifest)
          expect(job).to receive(:process_release)

          job.perform
        end

        context 'with multiple digests' do
          context 'when the digest matches' do
            let(:job_options) do
              {
                'remote' => true,
                'location' => 'release_location',
                'sha1' => "sha1:#{::Digest::SHA1.file(release_path).hexdigest}",
              }
            end

            it 'verifies that the digest matches the release' do
              allow(job).to receive(:release_path).and_return(release_path)

              expect(job).to receive(:download_remote_release)
              expect(job).to receive(:process_release)

              job.perform
            end
          end

          context 'when the digest does not match' do
            let(:status) { instance_double(Process::Status, exitstatus: 1) }
            let(:job_options) do
              { 'remote' => true, 'location' => 'release_location', 'sha1' => 'sha1:potato' }
            end

            it 'raises an error' do
              allow(job).to receive(:release_path).and_return(release_path)
              expect(job).to receive(:download_remote_release)

              expect do
                job.perform
              end.to raise_exception(Bosh::Director::ReleaseSha1DoesNotMatch, 'some error')
            end
          end
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
            'packages' => [],
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
          expect do
            job.perform
          end.to raise_exception(Bosh::Director::ReleaseInvalidArchive)
        end

        it 'deletes release archive and the release dir' do
          expect(FileUtils).to receive(:rm_rf).with(release_dir)
          expect(FileUtils).to receive(:rm_rf).with(release_path)

          expect do
            job.perform
          end.to raise_exception(Bosh::Director::ReleaseInvalidArchive)
        end
      end

      it 'saves release version and sets update_completed flag' do
        job.perform

        rv = Models::ReleaseVersion.filter(version: '42+dev.6').first
        expect(rv.update_completed).to be(true)
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
        let!(:release_version_model) { FactoryBot.create(:models_release_version, release: release, version: '42+dev.6', commit_hash: '12345678', uncommitted_changes: true) }

        context 'when rebase is passed' do
          let(:job_options) do
            { 'rebase' => true }
          end

          context 'when there are package changes' do
            let(:manifest_packages) do
              [
                {
                  'sha1' => 'fakesha1',
                  'fingerprint' => 'fake-fingerprint-1',
                  'name' => 'fake-name-1',
                  'version' => 'fake-version-1',
                },
              ]
            end

            it 'sets a next release version' do
              allow(Jobs::UpdateRelease::PackageProcessor).to receive(:process).and_return [manifest_packages, [], []]
              allow(Jobs::UpdateRelease::PackagePersister).to receive(:persist)
              job.perform

              expect(Jobs::UpdateRelease::PackagePersister).to have_received(:persist).with(
                new_packages:          manifest_packages,
                existing_packages:     [],
                registered_packages:   [],
                compiled_release:      false,
                release_dir:           release_dir,
                fix:                   false,
                manifest:              manifest.tap { |m| m['packages'].each { |p| p['dependencies'] = [] } },
                release_version_model: Models::ReleaseVersion.last,
                release_model:         release,
              )
              rv = Models::ReleaseVersion.filter(version: '42+dev.7').first
              expect(rv).to_not be_nil
            end
          end

          context 'when there are no job and package changes' do
            it 'still can pass and set a next release version' do
              # it just generate the next release version without creating/registering package
              expect do
                job.perform
              end.to_not raise_error

              rv = Models::ReleaseVersion.filter(version: '42+dev.7').first
              expect(rv).to_not be_nil
            end
          end
        end

        context 'when skip_if_exists is passed' do
          let(:job_options) do
            { 'skip_if_exists' => true }
          end

          it 'does not create a release' do
            expect(Jobs::UpdateRelease::PackagePersister).not_to receive(:create_package)
            expect(job).not_to receive(:create_job)
            job.perform
          end
        end
      end

      context 'when the same release is uploaded with different commit hash' do
        let!(:previous_release_version) do
          FactoryBot.create(:models_release_version, release: release, version: '42+dev.6', commit_hash: 'bad123', uncommitted_changes: true)
        end

        it 'fails with a ReleaseVersionCommitHashMismatch exception' do
          expect do
            job.perform
          end.to raise_exception(Bosh::Director::ReleaseVersionCommitHashMismatch, /#{previous_release_version.commit_hash}/)
        end
      end

      context 'when the release version does not match database valid format' do
        before do
          # Without modifying `VALID_ID` it is not possible to trigger validation from
          # Sequel because `Bosh::Common::Version::ReleaseVersion` validation would be triggered instead
          stub_const('Bosh::Director::Models::VALID_ID', /^[a-z0-9]+$/i)
        end

        let(:release_version) { 'bad-version' }

        it 'raises an error ReleaseVersionInvalid' do
          expect do
            job.perform
          end.to raise_error(Sequel::ValidationFailed)
        end
      end

      context 'when there are packages in manifest' do
        let(:manifest_packages) do
          [
            {
              'sha1' => 'fakesha1',
              'fingerprint' => 'fake-fingerprint-1',
              'name' => 'fake-name-1',
              'version' => 'fake-version-1',
            },
            {
              'sha1' => 'fakesha2',
              'fingerprint' => 'fake-fingerprint-2',
              'name' => 'fake-name-2',
              'version' => 'fake-version-2',
            },
          ]
        end

        before do
          FactoryBot.create(:models_package, release: release, name: 'fake-name-1', version: 'fake-version-1', fingerprint: 'fake-fingerprint-1')
        end

        it 'raises an error if a different fingerprint was detected for an already existing package' do
          pkg = FactoryBot.create(:models_package, release: release, name: 'fake-name-2', version: 'fake-version-2', fingerprint: 'different-finger-print', sha1: 'fakesha2')
          release_version = FactoryBot.create(:models_release_version, release: release, version: '42+dev.6', commit_hash: '12345678', uncommitted_changes: true)
          release_version.add_package(pkg)

          expect do
            job.perform
          end.to raise_exception(
            Bosh::Director::ReleaseInvalidPackage,
            %r{package 'fake-name-2' had different fingerprint in previously uploaded release 'appcloud\/42\+dev.6'},
          )
        end
      end

      context 'when manifest contains jobs' do
        let(:manifest_jobs) do
          [
            {
              'name' => 'fake-job-1',
              'version' => 'fake-version-1',
              'sha1' => 'fakesha11',
              'fingerprint' => 'fake-fingerprint-1',
              'templates' => {},
            },
            {
              'name' => 'fake-job-2',
              'version' => 'fake-version-2',
              'sha1' => 'fake-sha1-2',
              'fingerprint' => 'fake-fingerprint-2',
              'templates' => {},
            },
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
          corrupted_job = FactoryBot.create(:models_template,
            release: release,
            name: 'fake-job-1',
            version: 'fake-version-1',
            fingerprint: 'different-finger-print',
            sha1: 'fakesha11',
          )
          release_version = FactoryBot.create(:models_release_version,
            release: release,
            version: '42+dev.6',
            commit_hash: '12345678',
            uncommitted_changes: true,
          )
          release_version.add_template(corrupted_job)

          allow(job).to receive(:process_packages)

          expect do
            job.perform
          end.to raise_exception(
            Bosh::Director::ReleaseExistingJobFingerprintMismatch,
            %r{job 'fake-job-1' had different fingerprint in previously uploaded release 'appcloud\/42\+dev.6'},
          )
        end

        it "creates jobs that don't already exist" do
          FactoryBot.create(:models_template,
            release: release,
            name: 'fake-job-1',
            version: 'fake-version-1',
            fingerprint: 'fake-fingerprint-1',
          )
          expect(job).to receive(:create_jobs).with([
                                                      {
                                                        'sha1' => 'fake-sha1-2',
                                                        'fingerprint' => 'fake-fingerprint-2',
                                                        'name' => 'fake-job-2',
                                                        'version' => 'fake-version-2',
                                                        'templates' => {},
                                                      },
                                                    ], release_dir)
          job.perform
        end

        context 'when the release contains no packages' do
          before do
            manifest.delete('packages')
          end
          it 'should not error' do
            allow(job).to receive(:create_jobs)
            expect { job.perform }.to_not raise_error
          end
        end
      end

      context 'when manifest contains packages and jobs' do
        let(:manifest_jobs) do
          [
            {
              'name' => 'zbz',
              'version' => '666',
              'templates' => {},
              'packages' => %w[zbb],
              'fingerprint' => 'job-fingerprint-3',
            },
          ]
        end
        let(:manifest_packages) do
          [
            {
              'name' => 'foo',
              'version' => '2.33-dev',
              'dependencies' => %w[bar],
              'fingerprint' => 'package-fingerprint-1',
              'sha1' => 'packagesha11',
            },
            {
              'name' => 'bar',
              'version' => '3.14-dev',
              'dependencies' => [],
              'fingerprint' => 'package-fingerprint-2',
              'sha1' => 'packagesha12',
            },
            {
              'name' => 'zbb',
              'version' => '333',
              'dependencies' => [],
              'fingerprint' => 'package-fingerprint-3',
              'sha1' => 'packagesha13',
            },
          ]
        end

        it 'process packages should include all packages from the manifest in the packages array, even previously existing ones' do
          pkg_foo = FactoryBot.create(:models_package, release: release, name: 'foo', version: '2.33-dev',
                                         fingerprint: 'package-fingerprint-1', sha1: 'packagesha11',
                                         blobstore_id: 'bs1')
          pkg_bar = FactoryBot.create(:models_package, release: release, name: 'bar', version: '3.14-dev',
                                         fingerprint: 'package-fingerprint-2', sha1: 'packagesha12',
                                         blobstore_id: 'bs2')
          pkg_zbb = FactoryBot.create(:models_package, release: release, name: 'zbb', version: '333',
                                         fingerprint: 'package-fingerprint-3', sha1: 'packagesha13',
                                         blobstore_id: 'bs3')
          release_version = FactoryBot.create(:models_release_version, release: release, version: '42+dev.6', commit_hash: '12345678',
                                                        uncommitted_changes: true, update_completed: true)
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
                'config/zb.yml.erb' => 'config/zb.yml',
              },
              'packages' => %w[foo bar],
              'fingerprint' => 'job-fingerprint-1',
            },
            {
              'name' => 'zaz',
              'version' => '0.2-dev',
              'templates' => {},
              'packages' => %w[bar],
              'fingerprint' => 'job-fingerprint-2',
            },
            {
              'name' => 'zbz',
              'version' => '666',
              'templates' => {},
              'packages' => %w[zbb],
              'fingerprint' => 'job-fingerprint-3',
            },
          ],
          'packages' => [
            {
              'name' => 'foo',
              'version' => '2.33-dev',
              'dependencies' => %w[bar],
              'fingerprint' => 'package-fingerprint-1',
              'sha1' => 'packagesha11',
            },
            {
              'name' => 'bar',
              'version' => '3.14-dev',
              'dependencies' => [],
              'fingerprint' => 'package-fingerprint-2',
              'sha1' => 'packagesha12',
            },
            {
              'name' => 'zbb',
              'version' => '333',
              'dependencies' => [],
              'fingerprint' => 'package-fingerprint-3',
              'sha1' => 'packagesha13',
            },
          ],
        }
      end

      before do
        @release_dir = Test::ReleaseHelper.new.create_release_tarball(manifest)
        @release_path = File.join(@release_dir, 'release.tgz')

        @job = Jobs::UpdateRelease.new(@release_path, 'rebase' => true)

        @release = FactoryBot.create(:models_release, name: 'appcloud')
        @rv = FactoryBot.create(:models_release_version, release: @release, version: '37')

        FactoryBot.create(:models_package, release: @release, name: 'foo', version: '2.7-dev')
        FactoryBot.create(:models_package, release: @release, name: 'bar', version: '42')

        FactoryBot.create(:models_template, release: @release, name: 'baz', version: '33.7-dev')
        FactoryBot.create(:models_template, release: @release, name: 'zaz', version: '17')

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
          FactoryBot.create(:models_package,
            release: @release,
            name: 'zbb',
            version: '25',
            fingerprint: 'package-fingerprint-3',
            sha1: 'packagesha1old',
          )
        end

        it 'creates new package (version) with copied blob (sha1)' do
          expect(blobstore).to receive(:create).exactly(6).times # creates new blobs for each package & job
          expect(blobstore).to receive(:get).exactly(1).times # copies the existing 'zbb' package
          @job.perform

          zbbs = Models::Package.filter(release_id: @release.id, name: 'zbb').all
          expect(zbbs.map(&:version)).to match_array(%w[25 333])

          # Fingerprints are the same because package contents did not change
          expect(zbbs.map(&:fingerprint)).to match_array(%w[package-fingerprint-3 package-fingerprint-3])

          # SHA1s are the same because first blob was copied
          expect(zbbs.map(&:sha1)).to match_array(%w[packagesha1old packagesha1old])
        end

        it 'associates newly created packages to the release version' do
          @job.perform

          rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first
          expect(rv.packages.map(&:version)).to match_array(%w[2.33-dev 3.14-dev 333])
          expect(rv.packages.map(&:fingerprint)).to match_array(
            %w[package-fingerprint-1 package-fingerprint-2 package-fingerprint-3],
          )
          expect(rv.packages.map(&:sha1)).to match_array(%w[packagesha11 packagesha12 packagesha1old])
        end
      end

      context 'when the package fingerprint matches multiple in the database' do
        before do
          FactoryBot.create(:models_package, release: @release, name: 'zbb', version: '25', fingerprint: 'package-fingerprint-3', sha1: 'packagesha125')
          FactoryBot.create(:models_package, release: @release, name: 'zbb', version: '26', fingerprint: 'package-fingerprint-3', sha1: 'packagesha126')
        end

        it 'creates new package (version) with copied blob (sha1)' do
          expect(blobstore).to receive(:create).exactly(6).times # creates new blobs for each package & job
          expect(blobstore).to receive(:get).exactly(1).times # copies the existing 'zbb' package
          @job.perform

          zbbs = Models::Package.filter(release_id: @release.id, name: 'zbb').all
          expect(zbbs.map(&:version)).to match_array(%w[26 25 333])

          # Fingerprints are the same because package contents did not change
          expect(zbbs.map(&:fingerprint)).to match_array(%w[package-fingerprint-3 package-fingerprint-3 package-fingerprint-3])

          # SHA1s are the same because first blob was copied
          expect(zbbs.map(&:sha1)).to match_array(%w[packagesha125 packagesha125 packagesha126])
        end

        it 'associates newly created packages to the release version' do
          @job.perform

          rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first
          expect(rv.packages.map(&:version)).to match_array(%w[2.33-dev 3.14-dev 333])
          expect(rv.packages.map(&:fingerprint)).to match_array(
            %w[package-fingerprint-1 package-fingerprint-2 package-fingerprint-3],
          )
          expect(rv.packages.map(&:sha1)).to match_array(%w[packagesha11 packagesha12 packagesha125])
        end
      end

      context 'when the package fingerprint is new' do
        before do
          FactoryBot.create(:models_package, release: @release, name: 'zbb', version: '25', fingerprint: 'package-fingerprint-old', sha1: 'packagesha125')
        end

        it 'creates new package (version) with new blob (sha1)' do
          expect(blobstore).to receive(:create).exactly(6).times # creates new blobs for each package & job
          expect(blobstore).to receive(:get).exactly(0).times # does not copy any existing packages or jobs
          @job.perform

          zbbs = Models::Package.filter(release_id: @release.id, name: 'zbb').all
          expect(zbbs.map(&:version)).to match_array(%w[25 333])

          # Fingerprints are different because package contents are different
          expect(zbbs.map(&:fingerprint)).to match_array(%w[package-fingerprint-old package-fingerprint-3])

          # SHA1s are different because package tars are different
          expect(zbbs.map(&:sha1)).to match_array(%w[packagesha125 packagesha13])
        end

        it 'associates newly created packages to the release version' do
          @job.perform

          rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first
          expect(rv.packages.map(&:version)).to match_array(%w[2.33-dev 3.14-dev 333])
          expect(rv.packages.map(&:fingerprint)).to match_array(
            %w[package-fingerprint-1 package-fingerprint-2 package-fingerprint-3],
          )
          expect(rv.packages.map(&:sha1)).to match_array(%w[packagesha11 packagesha12 packagesha13])
        end
      end

      context 'when the job fingerprint matches one in the database' do
        before do
          FactoryBot.create(:models_template, release: @release, name: 'zbz', version: '28', fingerprint: 'job-fingerprint-3')
        end

        it 'uses the new job blob' do
          expect(blobstore).to receive(:create).exactly(6).times # creates new blobs for each package & job
          expect(blobstore).to receive(:get).exactly(0).times # does not copy any existing packages or jobs
          @job.perform

          zbzs = Models::Template.filter(release_id: @release.id, name: 'zbz').all
          expect(zbzs.map(&:version)).to match_array(%w[28 666])
          expect(zbzs.map(&:fingerprint)).to match_array(%w[job-fingerprint-3 job-fingerprint-3])

          rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first
          expect(rv.templates.map(&:fingerprint)).to match_array(%w[job-fingerprint-1 job-fingerprint-2 job-fingerprint-3])
        end
      end

      context 'when the job fingerprint is new' do
        before do
          FactoryBot.create(:models_template, release: @release, name: 'zbz', version: '28', fingerprint: 'job-fingerprint-old')
        end

        it 'uses the new job blob' do
          expect(blobstore).to receive(:create).exactly(6).times # creates new blobs for each package & job
          expect(blobstore).to receive(:get).exactly(0).times # does not copy any existing packages or jobs
          @job.perform

          zbzs = Models::Template.filter(release_id: @release.id, name: 'zbz').all
          expect(zbzs.map(&:version)).to match_array(%w[28 666])
          expect(zbzs.map(&:fingerprint)).to match_array(%w[job-fingerprint-old job-fingerprint-3])

          rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first
          expect(rv.templates.map(&:fingerprint)).to match_array(%w[job-fingerprint-1 job-fingerprint-2 job-fingerprint-3])
        end
      end

      it 'uses major+dev.1 version for initial rebase if no version exists' do
        @rv.destroy
        Models::Package.each(&:destroy)
        Models::Template.each(&:destroy)

        @job.perform

        foos = Models::Package.filter(release_id: @release.id, name: 'foo').all
        bars = Models::Package.filter(release_id: @release.id, name: 'bar').all

        expect(foos.map(&:version)).to match_array(%w[2.33-dev])
        expect(bars.map(&:version)).to match_array(%w[3.14-dev])

        bazs = Models::Template.filter(release_id: @release.id, name: 'baz').all
        zazs = Models::Template.filter(release_id: @release.id, name: 'zaz').all

        expect(bazs.map(&:version)).to match_array(%w[33])
        expect(zazs.map(&:version)).to match_array(%w[0.2-dev])

        rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first

        expect(rv.packages.map(&:version)).to match_array(%w[2.33-dev 3.14-dev 333])
        expect(rv.templates.map(&:version)).to match_array(%w[0.2-dev 33 666])
      end

      it 'performs the rebase if same release is being rebased twice', if: ENV.fetch('DB', 'sqlite') != 'sqlite' do
        allow(Config).to receive_message_chain(:current_job, :username).and_return('username')
        task = FactoryBot.create(:models_task, state: 'processing')
        allow(Config).to receive_message_chain(:current_job, :task_id).and_return(task.id)

        Config.configure(SpecHelper.spec_get_director_config)
        @job.perform

        @release_dir = Test::ReleaseHelper.new.create_release_tarball(manifest)
        @release_path = File.join(@release_dir, 'release.tgz')
        @job = Jobs::UpdateRelease.new(@release_path, 'rebase' => true)

        expect do
          @job.perform
        end.to_not raise_error

        rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.2').first
        expect(rv).to_not be_nil
      end
    end

    describe 'uploading release with --fix' do
      subject(:job) { Jobs::UpdateRelease.new(release_path, 'fix' => true) }
      let(:release_dir) { Test::ReleaseHelper.new.create_release_tarball(manifest) }
      let(:release_path) { File.join(release_dir, 'release.tgz') }
      let!(:release) { FactoryBot.create(:models_release, name: 'appcloud') }

      let!(:release_version_model) do
        FactoryBot.create(:models_release_version,
          release: release,
          version: '42+dev.1',
          commit_hash: '12345678',
          uncommitted_changes: true,
        )
      end
      before do
        allow(Dir).to receive(:mktmpdir).and_return(release_dir)
        allow(job).to receive(:with_release_lock).and_yield
      end

      context 'when uploading source release' do
        let(:manifest) do
          {
            'name' => 'appcloud',
            'version' => '42+dev.1',
            'commit_hash' => '12345678',
            'uncommitted_changes' => true,
            'jobs' => manifest_jobs,
            'packages' => manifest_packages,
          }
        end
        let(:manifest_jobs) do
          [
            {
              'sha1' => 'fakesha2',
              'fingerprint' => 'fake-fingerprint-2',
              'name' => 'fake-name-2',
              'version' => 'fake-version-2',
              'packages' => [
                'fake-name-1',
              ],
              'templates' => {},
            },
          ]
        end
        let(:manifest_packages) do
          [
            {
              'sha1' => 'fakesha1',
              'fingerprint' => 'fake-fingerprint-1',
              'name' => 'fake-name-1',
              'version' => 'fake-version-1',
              'dependencies' => [],
            },
          ]
        end

        context 'when release already exists' do
          let!(:package) do
            package = FactoryBot.create(:models_package,
              release: release,
              name: 'fake-name-1',
              version: 'fake-version-1',
              fingerprint: 'fake-fingerprint-1',
              blobstore_id: 'fake-pkg-blobstore-id-1',
              sha1: 'fakesha1',
            )
            release_version_model.add_package(package)
            package
          end

          let!(:template) do
            template = FactoryBot.create(:models_template,
              release: release,
              name: 'fake-name-2',
              version: 'fake-version-2',
              fingerprint: 'fake-fingerprint-2',
              blobstore_id: 'fake-job-blobstore-id-2',
              sha1: 'fakesha2',
            )
            release_version_model.add_template(template)
            template
          end

          it 're-uploads all blobs to replace old ones' do
            expect(BlobUtil).to receive(:delete_blob).with('fake-pkg-blobstore-id-1')
            expect(BlobUtil).to receive(:delete_blob).with('fake-job-blobstore-id-2')

            expect(BlobUtil).to receive(:create_blob).with(
              File.join(release_dir, 'packages', 'fake-name-1.tgz'),
            ).and_return('new-blobstore-id-after-fix')

            expect(BlobUtil).to receive(:create_blob).with(
              File.join(release_dir, 'jobs', 'fake-name-2.tgz'),
            ).and_return('new-job-blobstore-id-after-fix')

            job.perform

            expect(template.reload.blobstore_id).to eq('new-job-blobstore-id-after-fix')
          end
        end

        context 'when there are existing packages from another release' do
          let!(:another_release) { FactoryBot.create(:models_release, name: 'foocloud') }
          let!(:old_release_version_model) do
            FactoryBot.create(:models_release_version,
              release: another_release,
              version: '41+dev.1',
              commit_hash: '23456789',
              uncommitted_changes: true,
            )
          end

          let!(:existing_pkg) do
            package = FactoryBot.create(:models_package,
              release: another_release,
              name: 'fake-name-1',
              version: 'fake-version-1',
              fingerprint: 'fake-fingerprint-1',
              blobstore_id: 'existing-fake-blobstore-id-1',
              sha1: 'existing-fakesha1',
            )

            old_release_version_model.add_package(package)
            package
          end

          it 'does NOT attempt to fix the existing package in another release' do
            expect(BlobUtil).to_not receive(:delete_blob).with('existing-fake-blobstore-id-1')
            job.perform

            existing_pkg.reload
            expect(existing_pkg.sha1).to eq('existing-fakesha1')
            expect(existing_pkg.blobstore_id).to eq('existing-fake-blobstore-id-1')
          end
        end

        context 'eliminates compiled packages' do
          let!(:package) do
            package = FactoryBot.create(:models_package,
              release: release,
              name: 'fake-name-1',
              version: 'fake-version-1',
              fingerprint: 'fake-fingerprint-1',
              blobstore_id: 'fake-pkg-blobstore-id-1',
              sha1: 'fakepkgsha1',
            )
            release_version_model.add_package(package)
            package
          end
          let!(:compiled_package) do
            FactoryBot.create(:models_compiled_package,
              package: package,
              sha1: 'fakecompiledsha1',
              blobstore_id: 'fake-compiled-pkg-blobstore-id-1',
              dependency_key: 'fake-dep-key-1',
              stemcell_os: 'windows me',
              stemcell_version: '4.5',
            )
          end

          it 'eliminates package when broken or missing' do
            expect(BlobUtil).to receive(:delete_blob).with('fake-pkg-blobstore-id-1')
            expect(BlobUtil).to receive(:create_blob).with(
              File.join(release_dir, 'packages', 'fake-name-1.tgz'),
            ).and_return('new-pkg-blobstore-id-1')
            expect(BlobUtil).to receive(:create_blob).with(
              File.join(release_dir, 'jobs', 'fake-name-2.tgz'),
            ).and_return('new-job-blobstore-id-1')
            expect(BlobUtil).to receive(:delete_blob).with('fake-compiled-pkg-blobstore-id-1')
            expect do
              job.perform
            end.to change { Models::CompiledPackage.dataset.count }.from(1).to(0)
          end
        end
      end

      context 'when uploading compiled release' do
        let(:manifest_jobs) { [] }
        let(:manifest_compiled_packages) do
          [
            {
              'sha1' => 'fakesha1',
              'fingerprint' => 'fake-fingerprint-1',
              'name' => 'fake-name-1',
              'version' => 'fake-version-1',
              'stemcell' => 'macintosh os/7.1',
            },
          ]
        end
        let(:manifest) do
          {
            'name' => 'appcloud',
            'version' => '42+dev.1',
            'commit_hash' => '12345678',
            'uncommitted_changes' => true,
            'jobs' => manifest_jobs,
            'compiled_packages' => manifest_compiled_packages,
          }
        end

        context 'when release already exists' do
          let!(:package) do
            package = FactoryBot.create(:models_package,
              release: release,
              name: 'fake-name-1',
              version: 'fake-version-1',
              fingerprint: 'fake-fingerprint-1',
            )
            release_version_model.add_package(package)
            package
          end
          let!(:existing_compiled_package_with_different_dependencies) do
            compiled_package = FactoryBot.build(:models_compiled_package,
              blobstore_id: 'fake-compiled-blobstore-id-2',
              dependency_key: 'blarg',
              sha1: 'fakecompiledsha1',
              stemcell_os: 'macintosh os',
              stemcell_version: '7.1',
            )
            package.add_compiled_package compiled_package
            compiled_package
          end
          let!(:compiled_package) do
            compiled_package = FactoryBot.build(:models_compiled_package,
              blobstore_id: 'fake-compiled-blobstore-id-1',
              dependency_key: '[]',
              sha1: 'fakecompiledsha1',
              stemcell_os: 'macintosh os',
              stemcell_version: '7.1',
            )
            package.add_compiled_package compiled_package
            compiled_package
          end

          it 're-uploads all compiled packages to replace old ones' do
            expect(BlobUtil).to receive(:delete_blob).with('fake-compiled-blobstore-id-1')
            expect(BlobUtil).to receive(:create_blob).with(
              File.join(release_dir, 'compiled_packages', 'fake-name-1.tgz'),
            ).and_return('new-compiled-blobstore-id-after-fix')
            expect do
              job.perform
            end.to change {
              compiled_package.reload.blobstore_id
            }.from('fake-compiled-blobstore-id-1').to('new-compiled-blobstore-id-after-fix')
          end
        end

        context 'when re-using existing compiled packages from other releases' do
          let!(:another_release) { FactoryBot.create(:models_release, name: 'foocloud') }
          let!(:old_release_version_model) do
            FactoryBot.create(:models_release_version,
              release: another_release,
              version: '41+dev.1',
              commit_hash: '23456789',
              uncommitted_changes: true,
            )
          end
          let!(:existing_package) do
            package = FactoryBot.create(:models_package,
              release: another_release,
              name: 'fake-name-1',
              version: 'fake-version-1',
              fingerprint: 'fake-fingerprint-1',
            )

            old_release_version_model.add_package(package)
            package
          end
          let!(:existing_package_with_same_fingerprint) do
            package = FactoryBot.create(:models_package,
              release: another_release,
              name: 'fake-name-1',
              version: 'fake-version-2',
              fingerprint: 'fake-fingerprint-1',
            )

            old_release_version_model.add_package(package)
            package
          end

          let!(:existing_compiled_package_with_different_dependencies) do
            existing_compiled_package = FactoryBot.create(:models_compiled_package,
              blobstore_id: 'fake-existing-compiled-blobstore-id-2',
              dependency_key: 'fake-existing-compiled-dependency-key-1-other',
              sha1: 'fakeexistingcompiledsha1',
              stemcell_os: 'macintosh os',
              stemcell_version: '7.1',
            )
            existing_package.add_compiled_package existing_compiled_package
            existing_compiled_package
          end

          let!(:existing_compiled_package) do
            FactoryBot.build(:models_compiled_package,
              blobstore_id: 'fake-existing-compiled-blobstore-id-1',
              dependency_key: '[]',
              sha1: 'fakeexistingcompiledsha1',
              stemcell_os: 'macintosh os',
              stemcell_version: '7.1',
            ).tap { |c| existing_package.add_compiled_package(c) }
          end

          let!(:matching_existing_compiled_package_from_same_release_version) do
            FactoryBot.build(:models_compiled_package,
              blobstore_id: 'fake-existing-compiled-blobstore-id-A',
              dependency_key: '[]',
              sha1: 'fakeexistingcompiledsha1',
              stemcell_os: 'macintosh os',
              stemcell_version: '7.1',
            ).tap { |c| existing_package_with_same_fingerprint.add_compiled_package(c) }
          end

          it 'replaces existing compiled packages and copy blobs' do
            expect(BlobUtil).to receive(:delete_blob).with('fake-existing-compiled-blobstore-id-1')
            expect(BlobUtil).to receive(:delete_blob).with('fake-existing-compiled-blobstore-id-A')
            expect(BlobUtil).to receive(:create_blob).with(
              File.join(release_dir, 'compiled_packages', 'fake-name-1.tgz'),
            ).and_return('new-existing-compiled-blobstore-id-after-fix', 'new-existing-compiled-blobstore-id-A-after-fix')
            expect(BlobUtil).to receive(:copy_blob).with(
              'new-existing-compiled-blobstore-id-after-fix',
            ).and_return('new-compiled-blobstore-id')
            expect(existing_compiled_package.reload.blobstore_id).to eq('fake-existing-compiled-blobstore-id-1')
            expect(matching_existing_compiled_package_from_same_release_version.reload.blobstore_id).to eq('fake-existing-compiled-blobstore-id-A')
            job.perform
            expect(existing_compiled_package.reload.blobstore_id).to eq('new-existing-compiled-blobstore-id-after-fix')
            expect(matching_existing_compiled_package_from_same_release_version.reload.blobstore_id).to eq('new-existing-compiled-blobstore-id-A-after-fix')
          end
        end
      end
    end

    describe 'resolve_package_dependencies' do
      before do
        @job = Jobs::UpdateRelease.new('fake-release-path')
      end

      it 'should normalize nil dependencies' do
        packages = [
          { 'name' => 'A' },
          { 'name' => 'B', 'dependencies' => ['A'] },
        ]
        @job.resolve_package_dependencies(packages)
        expect(packages).to eql([
                                  { 'name' => 'A', 'dependencies' => [] },
                                  { 'name' => 'B', 'dependencies' => ['A'] },
                                ])
      end

      it 'should not allow cycles' do
        packages = [
          { 'name' => 'A', 'dependencies' => ['B'] },
          { 'name' => 'B', 'dependencies' => ['A'] },
        ]
        expect { @job.resolve_package_dependencies(packages) }.to raise_error(/Cycle: A=/)
      end
    end

    describe 'process_release' do
      subject(:job) { Jobs::UpdateRelease.new(release_path) }
      let(:release_dir) { Test::ReleaseHelper.new.create_release_tarball(manifest) }
      let(:release_path) { File.join(release_dir, 'release.tgz') }
      let(:manifest) do
        {
          'name' => 'appcloud',
          'version' => release_version,
          'commit_hash' => '12345678',
          'uncommitted_changes' => false,
          'jobs' => manifest_jobs,
          'packages' => manifest_packages,
        }
      end
      let(:release_version) { '42+dev.6' }
      let(:release) { FactoryBot.create(:models_release, name: 'appcloud') }
      let(:manifest_packages) { nil }
      let(:manifest_jobs) { nil }
      let(:extracted_release_dir) { job.extract_release }

      before do
        allow(Dir).to receive(:mktmpdir).and_return(release_dir)
        job.verify_manifest(extracted_release_dir)
      end

      context 'when upload release fails' do
        shared_examples_for 'failed release update' do
          it 'flags release as uncompleted' do
            allow(job).to receive(:process_jobs).and_raise('Intentional error')

            expect { job.process_release(extracted_release_dir) }.to raise_error('Intentional error')

            rv = Models::ReleaseVersion.filter(version: release_version).first
            expect(rv.update_completed).to be(false)
          end
        end

        context 'on a new release' do
          include_examples 'failed release update'
        end

        context 'on an already uploaded release' do
          before do
            FactoryBot.create(:models_release_version, release: release, version: '42+dev.6', commit_hash: '12345678',
                                        update_completed: true)
          end

          include_examples 'failed release update'
        end

        context 'on an already uploaded but uncompleted release' do
          it 'fixes the release' do
            FactoryBot.create(:models_release_version, release: release, version: '42+dev.6', commit_hash: '12345678',
                                        update_completed: false)

            job.process_release(extracted_release_dir)

            expect(job.fix).to be(true)
            rv = Models::ReleaseVersion.filter(version: release_version).first
            expect(rv.update_completed).to be(true)
          end
        end
      end
    end

    describe 're-using existing packages' do
      subject(:job) { Jobs::UpdateRelease.new(release_path, {}) }

      let(:manifest) do
        {
          'name' => 'appcloud',
          'version' => release_version,
          'commit_hash' => '12345678',
          'uncommitted_changes' => true,
          'jobs' => [],
          'packages' => manifest_packages,
        }
      end

      let(:manifest_packages) do
        [
          {
            'sha1' => 'fakesha1',
            'fingerprint' => 'fake-fingerprint-1',
            'name' => 'fake-name-1',
            'version' => 'fake-version-1',
          },
        ]
      end

      let(:release_dir) { Test::ReleaseHelper.new.create_release_tarball(manifest, skip_packages: true) }
      let(:release_path) { File.join(release_dir, 'release.tgz') }
      let(:release_version) { '42+dev.6' }
      let(:release) { FactoryBot.create(:models_release, name: 'appcloud') }
      let(:other_release) { FactoryBot.create(:models_release, name: 'other-release') }
      let(:release_version_model) do
        FactoryBot.create(:models_release_version,
          release: release,
          version: release_version,
          commit_hash: '12345678',
          uncommitted_changes: true,
          update_completed: true,
        )
      end

      let!(:existing_package_without_source) do
        FactoryBot.create(:models_package,
          fingerprint: 'fake-fingerprint-1',
          name: 'fake-name-1',
          version: 'fake-version-1',
          release: release,
          blobstore_id: nil,
          sha1: nil,
        )
      end

      let!(:existing_package_with_source_and_different_release) do
        FactoryBot.create(:models_package,
          fingerprint: 'fake-fingerprint-1',
          name: 'fake-name-1',
          version: 'fake-version-1',
          release: other_release,
        )
      end

      before do
        allow(job).to receive(:with_release_lock).and_yield
        allow(blobstore).to receive(:get).and_return([existing_package_with_source_and_different_release])
        allow(blobstore).to receive(:create).and_return(existing_package_with_source_and_different_release.blobstore_id)
      end

      it 'copies the source from the other releases package' do
        expect do
          subject.perform
        end.to_not raise_error

        expect(existing_package_without_source.reload.blobstore_id).to(
          eq(existing_package_with_source_and_different_release.blobstore_id),
        )
      end

      context 'when the package is already associated with the release version' do
        before do
          release_version_model.add_package(existing_package_without_source)
        end

        it 'backfills the source for the existing package from other packages' do
          expect do
            subject.perform
          end.to_not raise_error

          expect(existing_package_without_source.reload.blobstore_id).to(
            eq(existing_package_with_source_and_different_release.blobstore_id),
          )
        end
      end
    end
  end
end
