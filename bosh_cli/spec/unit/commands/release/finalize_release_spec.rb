require 'spec_helper'

module Bosh::Cli::Command::Release

  ORIG_DEV_VERSION = '8.1+dev.3'

  describe FinalizeRelease do
    subject(:command) { FinalizeRelease.new }

    describe '#finalize' do
      let(:fake_manifest) do
        <<-MANIFEST
          { 'name': 'my-release',
            'version': '#{ORIG_DEV_VERSION}',
            'packages': [],
            'jobs': [],
            'license': ~
          }
        MANIFEST
      end
      let(:release) { instance_double('Bosh::Cli::Release') }
      let(:file) {instance_double(File)}
      let(:tarball) { instance_double('Bosh::Cli::ReleaseTarball') }
      let(:blob_manager) { instance_double('Bosh::Cli::BlobManager') }
      let(:blobstore) { instance_double('Bosh::Blobstore::Client') }
      let(:archive_builder) { instance_double('Bosh::Cli::ArchiveBuilder') }
      let(:version_index) { instance_double('Bosh::Cli::Versions::VersionsIndex') }
      let(:release_version_index) { instance_double('Bosh::Cli::Versions::ReleaseVersionsIndex') }
      before do

        allow(command).to receive(:check_if_release_dir)
        allow(command).to receive(:show_summary)
        allow(command).to receive(:release).and_return(release)

        allow(release).to receive(:save_config)
        allow(release).to receive(:latest_release_filename=)
        allow(release).to receive(:latest_release_filename).and_return('foo-1.yml')
        allow(release).to receive(:blobstore).and_return(blobstore)

        allow(File).to receive(:open).and_return(file)
        allow(file).to receive(:puts)

        allow(Bosh::Cli::ReleaseTarball).to receive(:new).and_return(tarball)
        allow(tarball).to receive(:manifest).and_return(fake_manifest)
        allow(tarball).to receive(:exists?).and_return(true)
        allow(tarball).to receive(:valid?).and_return(true)
        allow(tarball).to receive(:version).and_return(ORIG_DEV_VERSION)
        allow(tarball).to receive(:replace_manifest)
        allow(tarball).to receive(:create_from_unpacked)
        allow(tarball).to receive(:license_resource).and_return('this is the license resource')

        allow(Bosh::Cli::BlobManager).to receive(:new).and_return(blob_manager)
        allow(blob_manager).to receive(:sync)
        allow(blob_manager).to receive(:print_status)
        allow(blob_manager).to receive(:dirty?).and_return(false)

        allow(Bosh::Cli::ArchiveBuilder).to receive(:new).and_return(archive_builder)
        allow(archive_builder).to receive(:build)

        allow(Bosh::Cli::Versions::VersionsIndex).to receive(:new).and_return(version_index)
        allow(version_index).to receive(:version_strings).and_return([])
        allow(version_index).to receive(:add_version)

        allow(Bosh::Cli::Versions::ReleaseVersionsIndex).to receive(:new).and_return(release_version_index)
        allow(release_version_index).to receive(:latest_version).and_return(Bosh::Common::Version::ReleaseVersion.parse('2'))
      end

      it 'is a command with the correct options' do
       command = Bosh::Cli::Config.commands['finalize release']
       expect(command).to have_options
       expect(command.options.map(&:first)).to match_array([
         '--dry-run',
         '--name NAME',
         '--version VERSION',
       ])
      end

      it 'fails when nonexistent tarball is specified' do
        allow(tarball).to receive(:exists?).and_return(false)
        expect { command.finalize('nonexistent.tgz') }.to raise_error(Bosh::Cli::CliError, 'Cannot find release tarball nonexistent.tgz')
      end

      it 'uses given name if --name is specified' do
        command.options[:name] = 'custom-final-release-name'
        command.finalize('ignored.tgz')
        expect(tarball).to have_received(:replace_manifest).with(hash_including('name' => 'custom-final-release-name'))
      end

      it 'uses name from tarball manifest if --name not specified' do
        command.finalize('ignored.tgz')
        expect(tarball).to have_received(:replace_manifest).with(hash_including('name' => 'my-release'))
      end

      it 'uses given final version if --version is specified' do
        command.options[:version] = '77'
        command.finalize('ignored.tgz')
        expect(tarball).to have_received(:replace_manifest).with(hash_including('version' => '77'))
      end

      it 'uses next final release version if --version not specified' do
        command.finalize('ignored.tgz')
        expect(tarball).to have_received(:replace_manifest).with(hash_including('version' => '3'))
      end

      it 'if --version is specified and is already taken, show an already exists version error' do
        command.options[:version] = '3'
        # release_index = instance_double(Bosh::Cli::Versions::VersionsIndex)
        # allow(Bosh::Cli::Versions::VersionsIndex).to receive(:new).and_return(release_index)
        allow(version_index).to receive(:version_strings).and_return(%w(1 2 3 4 5))
        expect { command.finalize('ignored.tgz') }.to raise_error(Bosh::Cli::CliError, 'Release version already exists')
      end

      it 'creates the final release directory when it doesn''t exist' do
        command.options[:name] = 'new-release-name'

        expect(FileUtils).to receive(:mkdir_p).with('releases/new-release-name')

        command.finalize('ignored.tgz')
      end

      it 'updates the latest release filename to point to the finalized release' do
        command.finalize('ignored.tgz')
        expect(release).to have_received(:latest_release_filename=).with(File.absolute_path('releases/my-release/my-release-3.yml'))
        expect(release).to have_received(:save_config)
      end

      it 'saves the final release manifest into the release directory' do
        file = instance_double(File)
        expect(File).to receive(:open).with(File.absolute_path('releases/my-release/my-release-3.yml'), 'w').and_yield(file)
        expect(file).to receive(:puts).with(fake_manifest)
        command.finalize('ignored.tgz')
      end

      it 'updates release index file' do
        command.options[:version] = '3'
        command.finalize('ignored.tgz')
        expect(version_index).to have_received(:add_version).with(anything, 'version' => '3')
      end

      it 'creates the final release tarball' do
        command.finalize('ignored.tgz')
        expect(tarball).to have_received(:create_from_unpacked).with(File.absolute_path('releases/my-release/my-release-3.tgz'))
      end

      context 'with license in the release manifest' do
        let(:fake_manifest) do
          <<-MANIFEST
          { 'name': 'my-release',
            'version': '#{ORIG_DEV_VERSION}',
            'packages': [],
            'jobs': [],
            'license': {
              'version': 'oldfingerprint',
              'fingerprint': 'oldfingerprint',
              'sha1': 'oldsha1'
            }
          }
          MANIFEST
        end

        before do
          expect(archive_builder).to receive(:build)
                                       .with('this is the license resource')
                                       .and_return(Bosh::Cli::BuildArtifact.new('license', 'newfingerprint', 'path', 'newsha1', [], true, false))
        end

        it 'should update the sha1 of the license after rebuilding the resource' do
          new_manifest = {
            'name'=> 'my-release',
            'version'=> '3',
            'packages'=> [],
            'jobs'=> [],
            'license'=> {
              'version'=> 'newfingerprint',
              'sha1'=> 'newsha1',
              'fingerprint'=> 'newfingerprint'
            }
          }

          expect(tarball).to receive(:replace_manifest).with(new_manifest)

          command.finalize('ignored.tgz')
        end
      end

      context 'when a package with a matching fingerprint has a different sha1' do
        let(:fake_manifest) do
          <<-MANIFEST
          { 'name': 'my-release',
            'version': '#{ORIG_DEV_VERSION}',
            'packages': [
              {
                'name': 'testpackage',
                'version': 'packagefingerprint',
                'fingerprint': 'packagefingerprint',
                'sha1': 'original_sha1'
              },
              {
                'name': 'other_testpackage',
                'version': 'other_packagefingerprint',
                'fingerprint': 'other_packagefingerprint',
                'sha1': 'same_sha_for_this_package'
              }
            ],
            'jobs': [
              {
                'name': 'testjob',
                'version': 'jobfingerprint',
                'fingerprint': 'jobfingerprint',
                'sha1': 'old_sha_for_job'
              },
              {
                'name': 'other_testjob',
                'version': 'other_jobfingerprint',
                'fingerprint': 'other_jobfingerprint',
                'sha1': 'same_sha'
              }
            ]
          }
          MANIFEST
        end

        let(:new_manifest) do
          { 'name' => 'my-release',
            'version' => '3',
            'packages' => [
              {
                'name' => 'testpackage',
                'version' => 'packagefingerprint',
                'fingerprint' => 'packagefingerprint',
                'sha1' => 'different_sha_for_same_package'
              },
              {
                'name' => 'other_testpackage',
                'version'=> 'other_packagefingerprint',
                'fingerprint'=> 'other_packagefingerprint',
                'sha1'=> 'same_sha_for_this_package'
              }
            ],
            'jobs' => [
              {
                'name' => 'testjob',
                'version' => 'jobfingerprint',
                'fingerprint' => 'jobfingerprint',
                'sha1' => 'different_sha_for_same_job'
              },
              {
                'name' => 'other_testjob',
                'version' => 'other_jobfingerprint',
                'fingerprint' => 'other_jobfingerprint',
                'sha1' => 'same_sha'
              }
            ]
          }
        end

        let(:version_index) do
          versions_index = Bosh::Cli::Versions::VersionsIndex.new('/tmp/nonexistant1234path')
          expect(versions_index).to receive(:save).twice.and_return true
          versions_index.add_version(
            'packagefingerprint',
            {
              'name' => 'testpackage',
              'version'=> 'packagefingerprint',
              'fingerprint'=> 'packagefingerprint',
              'sha1'=> 'different_sha_for_same_package'
            }
          )
          versions_index.add_version(
            'jobfingerprint',
            {
              'name' => 'testjob',
              'version' => 'jobfingerprint',
              'fingerprint' => 'jobfingerprint',
              'sha1' => 'different_sha_for_same_job'
            }
          )
          versions_index
        end

        it 'uses sha1 from preexisting package' do
          allow(command).to receive(:final_builds_for_artifact).and_return(version_index)
          expect(tarball).to receive(:package_tarball_path).twice
          expect(tarball).to receive(:job_tarball_path).twice

          expect(tarball).to receive(:replace_manifest).with(new_manifest)
          command.finalize('mytarball.tgz')
        end
      end

      it 'can do a dry run' do
        command.options[:dry_run] = true
        command.finalize('ignored.tgz')
        expect(tarball).to_not have_received(:replace_manifest)
        expect(version_index).to_not have_received(:add_version)
        expect(tarball).to_not have_received(:create_from_unpacked)
        expect(archive_builder).to_not have_received(:build)
      end
    end
  end
end
