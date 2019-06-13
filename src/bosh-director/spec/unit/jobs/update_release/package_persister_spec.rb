require 'spec_helper'
require 'support/release_helper'
require 'digest'

module Bosh::Director
  module Jobs
    describe UpdateRelease::PackagePersister do
      describe 'PackagePersister#create_package' do
        let(:release_dir) { Dir.mktmpdir }
        after { FileUtils.rm_rf(release_dir) }

        before do
          allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
        end

        let(:release) { Models::Release.make }

        let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient', create: true) }

        it 'should create simple packages' do
          FileUtils.mkdir_p(File.join(release_dir, 'packages'))
          package_path = File.join(release_dir, 'packages', 'test_package.tgz')

          File.open(package_path, 'w') do |f|
            f.write(create_package('test' => 'test contents'))
          end

          expect(blobstore).to receive(:create)
            .with(satisfy { |obj| obj.path == package_path })
            .and_return('blob_id')

          Jobs::UpdateRelease::PackagePersister.create_package(Logging::Logger.new, release, false, false, {
            'name' => 'test_package',
            'version' => '1.0',
            'sha1' => 'some-sha',
            'dependencies' => %w[foo_package bar_package],
          }, release_dir)

          package = Models::Package[name: 'test_package', version: '1.0']
          expect(package).not_to be_nil
          expect(package.name).to eq('test_package')
          expect(package.version).to eq('1.0')
          expect(package.release).to eq(release)
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

          Jobs::UpdateRelease::PackagePersister.create_package(Logging::Logger.new, release, false, false, {
            'name' => 'test_package',
            'version' => '1.0', 'sha1' => 'some-sha',
            'dependencies' => %w[foo_package bar_package],
            'blobstore_id' => 'blah'
          }, release_dir)

          package = Models::Package[name: 'test_package', version: '1.0']
          expect(package).not_to be_nil
          expect(package.name).to eq('test_package')
          expect(package.version).to eq('1.0')
          expect(package.release).to eq(release)
          expect(package.sha1).to eq('some-sha')
          expect(package.blobstore_id).to eq('blob_id')
        end

        it 'should fail if cannot extract package archive' do
          result = Bosh::Exec::Result.new('cmd', 'output', 1)
          expect(Bosh::Exec).to receive(:sh).and_return(result)

          expect do
            Jobs::UpdateRelease::PackagePersister.create_package(Logging::Logger.new, release, false, false, {
              'name' => 'test_package',
              'version' => '1.0',
              'sha1' => 'some-sha',
              'dependencies' => %w[foo_package bar_package],
            }, release_dir)
          end.to raise_exception(Bosh::Director::PackageInvalidArchive)
        end

        def create_package(files)
          io = StringIO.new

          Archive::Tar::Minitar::Writer.open(io) do |tar|
            files.each do |key, value|
              tar.add_file(key, mode: '0644', mtime: 0) { |os, _| os.write(value) }
            end
          end

          io.close
          gzip(io.string)
        end
      end

      describe 'create_package_for_compiled_release' do
        let(:release_dir) { Dir.mktmpdir }
        after { FileUtils.rm_rf(release_dir) }

        let(:release) { Models::Release.make }

        it 'should create simple packages without blobstore_id or sha1' do
          Jobs::UpdateRelease::PackagePersister.create_package(Logging::Logger.new, release, false, true, {
            'name' => 'test_package',
            'version' => '1.0',
            'sha1' => nil,
            'dependencies' => %w[foo_package bar_package],
          }, release_dir)

          package = Models::Package[name: 'test_package', version: '1.0']
          expect(package).not_to be_nil
          expect(package.name).to eq('test_package')
          expect(package.version).to eq('1.0')
          expect(package.release).to eq(release)
          expect(package.sha1).to be_nil
          expect(package.blobstore_id).to be_nil
        end
      end

      describe 'Compiled release upload' do
        subject(:job) do
          Jobs::UpdateRelease::PackagePersister.new(
            manifest_compiled_packages,
            [],
            [],
            true,
            release_dir,
            false,
            manifest,
            release_version,
            release,
          )
        end

        let(:release_dir) { Test::ReleaseHelper.new.create_release_tarball(manifest) }
        let(:release_version) { '42+dev.6' }
        let(:release) { Models::Release.make(name: 'appcloud') }

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
        end

        it 'should process packages for compiled release' do
          expect(job).to receive(:create_packages)
          expect(job).to receive(:use_existing_packages)
          expect(job).to receive(:create_compiled_packages)

          job.persist
        end

        context 'when there are packages in manifest' do
          subject(:job) do
            Jobs::UpdateRelease::PackagePersister.new(
              manifest_packages,
              [],
              [],
              false,
              release_dir,
              false,
              manifest,
              release_version,
              release,
            )
          end

          let(:manifest_packages) do
            [
              {
                'sha1' => 'fakesha2',
                'fingerprint' => 'fake-fingerprint-2',
                'name' => 'fake-name-2',
                'version' => 'fake-version-2',
                'dependencies' => [],
                'compiled_package_sha1' => 'fakesha2',
              },
            ]
          end

          let(:release_dir) { Dir.mktmpdir }

          before do
            Models::Package.make(release: release, name: 'fake-name-1', version: 'fake-version-1', fingerprint: 'fake-fingerprint-1')
          end

          it "creates packages that don't already exist" do
            expect(job).to receive(:create_packages).with([
              {
                'sha1' => 'fakesha2',
                'fingerprint' => 'fake-fingerprint-2',
                'name' => 'fake-name-2',
                'version' => 'fake-version-2',
                'dependencies' => [],
                'compiled_package_sha1' => 'fakesha2',
              },
            ], release_dir)
            job.persist
          end
        end
      end
    end
  end
end
