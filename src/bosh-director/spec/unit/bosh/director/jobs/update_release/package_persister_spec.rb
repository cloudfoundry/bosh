require 'spec_helper'
require 'digest'

module Bosh::Director
  module Jobs
    describe UpdateRelease::PackagePersister do
      describe 'PackagePersister.persist' do
        describe 'Compiled release upload' do
          def persist_packages(manifest_packages, compiled_flag)
            Jobs::UpdateRelease::PackagePersister.persist(
              new_packages:          manifest_packages,
              existing_packages:     [],
              registered_packages:   [],
              compiled_release:      compiled_flag,
              release_dir:           release_dir,
              fix:                   false,
              manifest:              manifest,
              release_version_model: release_version_model,
              release_model:         release,
            )
          end

          let(:release_dir) { create_release_tarball(manifest) }
          let(:release_version) { '42+dev.6' }
          let(:release_version_model) { FactoryBot.create(:models_release_version, version: release_version) }
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
                'compiled_package_sha1' => 'compiled-sha1-1',
                'stemcell' => 'foo/bar',
                'dependencies' => [],
              },
              {
                'sha1' => 'fakesha2',
                'fingerprint' => 'fake-fingerprint-2',
                'name' => 'fake-name-2',
                'version' => 'fake-version-2',
                'compiled_package_sha1' => 'compiled-sha1-2',
                'stemcell' => 'foo/bar',
                'dependencies' => [],
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
            ['fake-name-1.tgz', 'fake-name-2.tgz'].each do |name|
              tgz = "#{release_dir}/compiled_packages/#{name}"
              allow(Bosh::Common::Exec).to receive(:sh).with(
                "tar -tzf #{tgz} 2>&1",
                on_error: :return,
              ).and_return(instance_double(Bosh::Common::Exec::Result, failed?: false))
              expect(BlobUtil).to receive(:create_blob).with(tgz).and_return(1)
            end
            expect(BlobUtil).to_not receive(:copy_blob)

            persist_packages(manifest_compiled_packages, true)
            packages = Models::Package.order(:name).all
            expect(packages.length).to eq(2)
            packages[0].tap do |p|
              expect(p.sha1).to eq(nil)
              expect(p.compiled_packages.length).to eq(1)
              expect(p.compiled_packages.first.sha1).to eq('compiled-sha1-1')
              expect(p.compiled_packages.first.dependency_key_sha1).to eq('97d170e1550eee4afc0af065b78cda302a97674c')
              expect(p.compiled_packages.first.stemcell_os).to eq('foo')
              expect(p.compiled_packages.first.stemcell_version).to eq('bar')
              expect(p.compiled_packages.first.build).to eq(1)
              expect(p.compiled_packages.first.blobstore_id).to eq('1')
              expect(p.fingerprint).to eq('fake-fingerprint-1')
              expect(p.name).to eq('fake-name-1')
              expect(p.version).to eq('fake-version-1')
            end
            packages[1].tap do |p|
              expect(p.sha1).to eq(nil)
              expect(p.compiled_packages.length).to eq(1)
              expect(p.compiled_packages.first.sha1).to eq('compiled-sha1-2')
              expect(p.compiled_packages.first.dependency_key_sha1).to eq('97d170e1550eee4afc0af065b78cda302a97674c')
              expect(p.compiled_packages.first.stemcell_os).to eq('foo')
              expect(p.compiled_packages.first.stemcell_version).to eq('bar')
              expect(p.compiled_packages.first.build).to eq(1)
              expect(p.compiled_packages.first.blobstore_id).to eq('1')
              expect(p.fingerprint).to eq('fake-fingerprint-2')
              expect(p.name).to eq('fake-name-2')
              expect(p.version).to eq('fake-version-2')
            end

            compiled_packages = Models::CompiledPackage.all
            expect(compiled_packages.length).to eq(2)
          end

          context 'when there is a collision between package fingerprints' do
            let(:manifest_compiled_packages) do
              [
                {
                  'sha1' => 'fakesha2',
                  'fingerprint' => 'same-fingerprint',
                  'name' => package_name_2,
                  'version' => 'fake-version-2',
                  'compiled_package_sha1' => 'compiled-sha1-2',
                  'stemcell' => 'foo/bar',
                  'dependencies' => [],
                },
              ]
            end

            before do
              other_release = FactoryBot.create(:models_release, name: 'other-release')
              existing_package = FactoryBot.create(:models_package,
                release: other_release,
                sha1: 'sha1-1',
                name: package_name_1,
                version: 'fake-version-1',
                fingerprint: 'same-fingerprint',
              )
              FactoryBot.create(:models_compiled_package,
                package: existing_package,
                sha1: 'compiled-sha1-1',
                stemcell_os: 'foo',
                stemcell_version: 'bar',
              )
            end

            context 'and the packages have different names' do
              let(:package_name_1) { 'fake-name-1' }
              let(:package_name_2) { 'fake-name-2' }

              it 'should not copy the existing blob' do
                ['fake-name-2.tgz'].each do |name|
                  tgz = "#{release_dir}/compiled_packages/#{name}"
                  allow(Bosh::Common::Exec).to receive(:sh).with(
                    "tar -tzf #{tgz} 2>&1",
                    on_error: :return,
                  ).and_return(instance_double(Bosh::Common::Exec::Result, failed?: false))
                  expect(BlobUtil).to receive(:create_blob).with(tgz).and_return(1)
                end
                expect(BlobUtil).to_not receive(:copy_blob)

                persist_packages(manifest_compiled_packages, true)
                new_package = Models::Package.all.find { |pkg| pkg.name == package_name_2 }
                new_package.tap do |p|
                  expect(p.sha1).to eq(nil)
                  expect(p.compiled_packages.length).to eq(1)
                  expect(p.compiled_packages.first.sha1).to eq('compiled-sha1-2')
                  expect(p.compiled_packages.first.dependency_key_sha1).to eq('97d170e1550eee4afc0af065b78cda302a97674c')
                  expect(p.compiled_packages.first.stemcell_os).to eq('foo')
                  expect(p.compiled_packages.first.stemcell_version).to eq('bar')
                  expect(p.compiled_packages.first.build).to eq(1)
                  expect(p.compiled_packages.first.blobstore_id).to eq('1')
                  expect(p.fingerprint).to eq('same-fingerprint')
                  expect(p.name).to eq(package_name_2)
                  expect(p.version).to eq('fake-version-2')
                end

                compiled_packages = Models::CompiledPackage.all
                expect(compiled_packages.length).to eq(2)
              end
            end

            context 'and the packages have the same name' do
              let(:package_name_1) { 'same-name' }
              let(:package_name_2) { 'same-name' }

              it 'should copy the existing blob' do
                ['fake-name-1.tgz', 'fake-name-2.tgz'].each do |name|
                  tgz = "#{release_dir}/compiled_packages/#{name}"
                  allow(Bosh::Common::Exec).to receive(:sh).with(
                    "tar -tzf #{tgz} 2>&1",
                    on_error: :return,
                  ).and_return(instance_double(Bosh::Common::Exec::Result, failed?: false))
                end
                expect(BlobUtil).to_not receive(:create_blob)
                expect(BlobUtil).to receive(:copy_blob).and_return('copied-blob-id')

                persist_packages(manifest_compiled_packages, true)
                new_package = Models::Package.where(name: package_name_2, version: 'fake-version-2').first
                new_package.tap do |p|
                  expect(p.sha1).to eq(nil)
                  expect(p.compiled_packages.length).to eq(1)
                  expect(p.compiled_packages.first.sha1).to eq('compiled-sha1-1')
                  expect(p.compiled_packages.first.dependency_key_sha1).to eq('97d170e1550eee4afc0af065b78cda302a97674c')
                  expect(p.compiled_packages.first.stemcell_os).to eq('foo')
                  expect(p.compiled_packages.first.stemcell_version).to eq('bar')
                  expect(p.compiled_packages.first.build).to eq(1)
                  expect(p.compiled_packages.first.blobstore_id).to eq('copied-blob-id')
                  expect(p.fingerprint).to eq('same-fingerprint')
                  expect(p.name).to eq(package_name_2)
                  expect(p.version).to eq('fake-version-2')
                end

                compiled_packages = Models::CompiledPackage.all
                expect(compiled_packages.length).to eq(2)
              end
            end
          end

          context 'when there are packages in manifest' do
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
              FactoryBot.create(:models_package,
                release: release,
                sha1: 'sha1-1',
                name: 'fake-name-1',
                version: 'fake-version-1',
                fingerprint: 'fake-fingerprint-1',
              )
            end

            it "creates packages that don't already exist" do
              tgz = "#{release_dir}/packages/fake-name-2.tgz"
              allow(Bosh::Common::Exec).to receive(:sh).with(
                "tar -tzf #{tgz} 2>&1",
                on_error: :return,
              ).and_return(instance_double(Bosh::Common::Exec::Result, failed?: false))
              expect(BlobUtil).to receive(:create_blob).with(tgz).and_return(1)

              persist_packages(manifest_packages, false)

              packages = Models::Package.all
              expect(packages.length).to eq(2)
              packages[0].tap do |p|
                expect(p.sha1).to eq('sha1-1')
                expect(p.fingerprint).to eq('fake-fingerprint-1')
                expect(p.name).to eq('fake-name-1')
                expect(p.version).to eq('fake-version-1')
              end
              packages[1].tap do |p|
                expect(p.sha1).to eq('fakesha2')
                expect(p.fingerprint).to eq('fake-fingerprint-2')
                expect(p.name).to eq('fake-name-2')
                expect(p.version).to eq('fake-version-2')
              end
            end
          end
        end
      end

      describe 'PackagePersister.create_package' do
        let(:release_dir) { Dir.mktmpdir }
        after { FileUtils.rm_rf(release_dir) }

        before do
          allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
        end

        let(:release) { FactoryBot.create(:models_release) }

        let(:blobstore) { instance_double('Bosh::Director::Blobstore::Client', create: true) }

        it 'should create simple packages' do
          FileUtils.mkdir_p(File.join(release_dir, 'packages'))
          package_path = File.join(release_dir, 'packages', 'test_package.tgz')

          File.open(package_path, 'w') do |f|
            f.write(create_release_package('test' => 'test contents'))
          end

          expect(blobstore).to receive(:create)
            .with(satisfy { |obj| obj.path == package_path })
            .and_return('blob_id')

          Jobs::UpdateRelease::PackagePersister.create_package(
            logger: Logging::Logger.new('Test-Logger'),
            release_model: release,
            fix: false,
            compiled_release: false,
            package_meta: {
              'name' => 'test_package',
              'version' => '1.0',
              'sha1' => 'some-sha',
              'dependencies' => %w[foo_package bar_package],
            },
            release_dir: release_dir,
          )

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
            f.write(create_release_package('test' => 'test contents'))
          end

          Jobs::UpdateRelease::PackagePersister.create_package(
            logger: Logging::Logger.new('Test-Logger'),
            release_model: release,
            fix: false,
            compiled_release: false,
            package_meta: {
              'name' => 'test_package',
              'version' => '1.0', 'sha1' => 'some-sha',
              'dependencies' => %w[foo_package bar_package],
              'blobstore_id' => 'blah'
            },
            release_dir: release_dir,
          )

          package = Models::Package[name: 'test_package', version: '1.0']
          expect(package).not_to be_nil
          expect(package.name).to eq('test_package')
          expect(package.version).to eq('1.0')
          expect(package.release).to eq(release)
          expect(package.sha1).to eq('some-sha')
          expect(package.blobstore_id).to eq('blob_id')
        end

        it 'should fail if cannot extract package archive' do
          result = Bosh::Common::Exec::Result.new('cmd', 'output', 1)
          expect(Bosh::Common::Exec).to receive(:sh).and_return(result)

          expect do
            Jobs::UpdateRelease::PackagePersister.create_package(
              logger: Logging::Logger.new,
              release_model: release,
              fix: false,
              compiled_release: false,
              package_meta: {
                'name' => 'test_package',
                'version' => '1.0',
                'sha1' => 'some-sha',
                'dependencies' => %w[foo_package bar_package],
              },
              release_dir: release_dir,
            )
          end.to raise_exception(Bosh::Director::PackageInvalidArchive)
        end

        describe 'compiled_releases' do
          let(:release_dir) { Dir.mktmpdir }
          after { FileUtils.rm_rf(release_dir) }

          let(:release) { FactoryBot.create(:models_release) }

          it 'should create simple packages without blobstore_id or sha1' do
            Jobs::UpdateRelease::PackagePersister.create_package(
              logger: Logging::Logger.new('Test-Logger'),
              release_model: release,
              fix: false,
              compiled_release: true,
              package_meta: {
                'name' => 'test_package',
                'version' => '1.0',
                'sha1' => nil,
                'dependencies' => %w[foo_package bar_package],
              },
              release_dir: release_dir,
            )

            package = Models::Package[name: 'test_package', version: '1.0']
            expect(package).not_to be_nil
            expect(package.name).to eq('test_package')
            expect(package.version).to eq('1.0')
            expect(package.release).to eq(release)
            expect(package.sha1).to be_nil
            expect(package.blobstore_id).to be_nil
          end
        end
      end
    end
  end
end
