require 'spec_helper'
require 'support/release_helper'
require 'digest'

module Bosh::Director
  module Jobs
    describe UpdateRelease::PackageProcessor do
      describe 'process_packages' do
        def process_packages
          UpdateRelease::PackageProcessor.process(
            release_dir,
            compiled_release,
            release_version_model,
            release_model,
            name,
            version,
            manifest_packages,
            logger,
            update_release,
          )
        end

        let(:update_release) { instance_double(UpdateRelease) }

        let(:release_dir) { double(:release_dir) }
        let(:manifest_packages) { [] }

        let(:compiled_release) { false }
        let(:release_version_model) { nil }
        let(:release_model) { nil }
        let(:name) { nil }
        let(:version) { nil }

        context 'if it is compiled' do
          let(:compiled_release) { true }

          it 'creates compiled packages' do
            expect(update_release).to receive(:create_packages).with([], release_dir)
            expect(update_release).to receive(:use_existing_packages).with([], release_dir)
            expect(update_release).to receive(:create_compiled_packages).with([], release_dir)

            process_packages
          end
        end

        context 'if it is not compiled' do
          let(:compiled_release) { false }

          it 'backfills source for packages' do
            expect(update_release).to receive(:create_packages).with([], release_dir)
            expect(update_release).to receive(:use_existing_packages).with([], release_dir)
            expect(update_release).to_not receive(:create_compiled_packages)

            expect(update_release).to receive(:backfill_source_for_packages).with([], release_dir)

            process_packages
          end
        end

        context 'if a package fingerprint changes' do
          let(:manifest_packages) do
            [
              { 'name' => 'package_a', 'fingerprint' => 'b' },
            ]
          end

          let(:release_version_model) { instance_double(Models::ReleaseVersion) }

          let(:name)    { 'release-name' }
          let(:version) { 'release-version' }

          before do
            allow(release_version_model).to receive(:packages).and_return [
              instance_double(Models::Package, name: 'package_a', fingerprint: 'a'),
            ]
          end

          it 'raises an exception' do
            expect do
              process_packages
            end.to raise_error(
              "package 'package_a' had different fingerprint in previously uploaded release 'release-name/release-version'",
            )
          end
        end

        context 'if there is no existing package with the same fingerprint' do
          let(:manifest_packages) do
            [new_package_metadata]
          end

          before do
            allow(release_version_model).to receive(:packages).and_return []
            allow(update_release).to receive(:create_packages).and_return(create_compiled_packages_response)
          end

          let(:new_package_metadata) do
            { 'name' => 'package-a', 'fingerprint' => 'print-a', 'sha1' => 'sha-a' }
          end

          let(:create_compiled_packages_response) { [double(:create_compiled_packages_response)] }

          let(:release_version_model) { instance_double(Models::ReleaseVersion) }

          it 'treats it as a new package' do
            expect(update_release).to receive(:use_existing_packages).with([], release_dir)
            expect(update_release).to receive(:backfill_source_for_packages).with([], release_dir)

            expect(update_release).to receive(:create_packages).with(
              [new_package_metadata.merge('compiled_package_sha1' => new_package_metadata['sha1'])],
              release_dir,
            )

            process_packages
          end

          context 'if it is compiled' do
            let(:compiled_release) { true }

            it 'creates compiled packages' do
              expect(update_release).to receive(:use_existing_packages).with([], release_dir)
              expect(update_release).to receive(:create_compiled_packages).with(create_compiled_packages_response, release_dir)

              process_packages
            end
          end

          context 'if it is not compiled' do
            let(:compiled_release) { false }

            it 'backfills source for packages, ignoring the new package' do
              expect(update_release).to receive(:use_existing_packages).with([], release_dir)
              expect(update_release).to receive(:backfill_source_for_packages).with([], release_dir)

              process_packages
            end
          end
        end

        context 'if there exists a package that has a matching fingerprint' do
          let(:manifest_packages) do
            [new_package_metadata]
          end

          let(:release_model) { double(id: 1) }

          let!(:release_version_model) do
            release.add_version(Models::ReleaseVersion.make)
          end

          let(:new_package_metadata) do
            {
              'name' => 'package-a',
              'version' => 'package-version',
              'fingerprint' => package_fingerprint,
              'sha1' => 'sha-a',
            }
          end

          let(:release) { Models::Release.make(name: 'appcloud') }
          let!(:package_model) do
            package_id = Models::Package.insert(
              name: package_name,
              fingerprint: package_fingerprint,
              sha1: model_sha,
              version: package_version,
              blobstore_id: blobstore_id,
              dependency_set_json: '{}',
              release_id: release.id,
            )
            Models::Package.where(id: package_id).first
          end

          let(:package_name) { 'package-a' }
          let(:package_version) { 'package-version' }
          let(:model_sha) { 'model-sha-a' }
          let(:package_fingerprint) { 'a' }
          let(:blobstore_id) { '1234' }

          context 'and is preexisting' do
            context 'and is not registered already' do
              context 'and has a non-nil blobstore id' do
                it 'does not change the package metadata' do
                  expect(update_release).to receive(:create_packages).with([], release_dir)
                  expect(update_release).to receive(:backfill_source_for_packages).with([], release_dir)
                  expect(update_release).to receive(:use_existing_packages).with(
                    [[
                      package_model,
                      new_package_metadata.merge('compiled_package_sha1' => new_package_metadata['sha1']),
                    ]],
                    release_dir,
                  )

                  process_packages
                end
              end

              context 'but has a nil blobstore id' do
                let(:blobstore_id) { nil }

                it 'copies the blobstore id from another package with the same fingerprint into the package metadata' do
                  another_blobstore_id = '2345'
                  another_model_sha1 = 'model-sha-b'
                  Models::Package.insert(
                    name: package_name,
                    fingerprint: package_fingerprint,
                    sha1: another_model_sha1,
                    version: package_version,
                    blobstore_id: another_blobstore_id,
                    dependency_set_json: '{}',
                    release_id: release.id,
                  )

                  expect(update_release).to receive(:create_packages).with([], release_dir)
                  expect(update_release).to receive(:backfill_source_for_packages).with([], release_dir)
                  expect(update_release).to receive(:use_existing_packages).with(
                    [[
                      package_model,
                      new_package_metadata.merge(
                        'compiled_package_sha1' => new_package_metadata['sha1'],
                        'blobstore_id' => another_blobstore_id,
                        'sha1' => another_model_sha1,
                      ),
                    ]],
                    release_dir,
                  )

                  process_packages
                end
              end
            end

            context 'and is registered already' do
              before do
                release_version_model.add_package(package_model)
              end

              context 'and is compiled' do
                let(:compiled_release) { true }

                it 'reshapes the existing packages to input into create_compiled_packages' do
                  expect(update_release).to receive(:create_packages).with([], release_dir)
                  expect(update_release).to receive(:use_existing_packages).with([], release_dir)
                  expect(update_release).to receive(:create_compiled_packages).with(
                    [{
                      package: package_model,
                      package_meta: new_package_metadata,
                    }],
                    release_dir,
                  )

                  process_packages
                end
              end

              context 'and is not compiled' do
                let(:compiled_release) { false }

                it 'backfills source for packages' do
                  expect(update_release).to receive(:create_packages).with([], release_dir)
                  expect(update_release).to receive(:use_existing_packages).with([], release_dir)
                  expect(update_release).to receive(:backfill_source_for_packages).with(
                    [[
                      package_model,
                      new_package_metadata.merge('compiled_package_sha1' => new_package_metadata['sha1']),
                    ]],
                    release_dir,
                  )

                  process_packages
                end
              end
            end
          end

          context 'and is not preexisting' do
            context 'and has a nil blobstore id' do
              let(:release_model) { double(id: 2) }

              let(:blobstore_id) { nil }

              it 'does not reuse the blob' do
                expect(update_release).to receive(:use_existing_packages).with([], release_dir)
                expect(update_release).to receive(:backfill_source_for_packages).with([], release_dir)
                expect(update_release).to receive(:create_packages).with(
                  [hash_excluding('blobstore_id' => blobstore_id, 'sha1' => model_sha)],
                  release_dir,
                )

                process_packages
              end
            end

            context 'and has a blobstore id' do
              let(:blobstore_id) { '1234' }

              context 'but does not match release id' do

                let(:release_model) { double(id: 2) }

                it 'copies metadata from the existing package' do
                  expect(update_release).to receive(:use_existing_packages).with([], release_dir)
                  expect(update_release).to receive(:backfill_source_for_packages).with([], release_dir)
                  expect(update_release).to receive(:create_packages).with(
                    [
                      new_package_metadata.merge(
                        'compiled_package_sha1' => new_package_metadata['sha1'],
                        'blobstore_id' => blobstore_id,
                        'sha1' => model_sha,
                      ),
                    ],
                    release_dir,
                  )

                  process_packages
                end
              end

              context 'but does not match name' do
                let(:package_name) { 'package-b' }

                it 'copies metadata from the existing package' do
                  expect(update_release).to receive(:use_existing_packages).with([], release_dir)
                  expect(update_release).to receive(:backfill_source_for_packages).with([], release_dir)
                  expect(update_release).to receive(:create_packages).with(
                    [
                      new_package_metadata.merge(
                        'compiled_package_sha1' => new_package_metadata['sha1'],
                        'blobstore_id' => blobstore_id,
                        'sha1' => model_sha,
                      ),
                    ],
                    release_dir,
                  )

                  process_packages
                end
              end

              context 'but does not match version' do
                let(:package_version) { 'package-version-abcd' }

                it 'copies metadata from the existing package' do
                  expect(update_release).to receive(:use_existing_packages).with([], release_dir)
                  expect(update_release).to receive(:backfill_source_for_packages).with([], release_dir)
                  expect(update_release).to receive(:create_packages).with(
                    [
                      new_package_metadata.merge(
                        'compiled_package_sha1' => new_package_metadata['sha1'],
                        'blobstore_id' => blobstore_id,
                        'sha1' => model_sha,
                      ),
                    ],
                    release_dir,
                  )

                  process_packages
                end
              end
            end
          end
        end
      end
    end
  end
end
