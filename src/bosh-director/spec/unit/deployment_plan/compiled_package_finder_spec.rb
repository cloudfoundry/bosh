require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::CompiledPackageFinder do
    include Support::StemcellHelpers

    context '#find_compiled_package' do
      let(:event_log_stage) { double('event_log_stage') }
      let(:example_release_model) { Models::Release.make }
      let(:example_stemcell) do
        DeploymentPlan::Stemcell.make(version: '1.2')
      end
      let(:exported_from) { [] }
      let(:release) do
        DeploymentPlan::ReleaseVersion.new(Models::Deployment.make, 'release-name', '42', exported_from)
      end

      let(:package_dependency_manager) { PackageDependenciesManager.new(example_release_model) }
      let(:dependency_key) { KeyGenerator.new.dependency_key_from_models(example_package, example_release_model) }

      let(:cache_key) do
        Models::CompiledPackage.create_cache_key(
          example_package,
          package_dependency_manager.transitive_dependencies(example_package),
          example_stemcell.sha1,
        )
      end

      let(:compiled_package_finder) do
        DeploymentPlan::CompiledPackageFinder.new(Config.logger)
      end

      context 'if the given package does not have source' do
        let(:example_package) { Models::Package.make(release: example_release_model, blobstore_id: nil, sha1: nil) }

        context 'and there is a compiled package that exactly matches the stemcell version' do
          let!(:exact_compiled_package) do
            Models::CompiledPackage.make(
              package: example_package,
              stemcell_version: example_stemcell.version,
              stemcell_os: example_stemcell.os,
              dependency_key: dependency_key,
            )
          end

          it 'returns an exact matched compiled package' do
            result = compiled_package_finder.find_compiled_package(
              package: example_package,
              stemcell: example_stemcell,
              dependency_key: dependency_key,
              cache_key: cache_key,
              event_log_stage: event_log_stage,
            )
            expect(result).to eq(exact_compiled_package)
          end
        end

        context 'and there are packages that match on the major stemcell line' do
          let!(:newer_compiled_package) do
            Models::CompiledPackage.make(
              package: example_package,
              stemcell_version: '1.3',
              stemcell_os: example_stemcell.os,
              dependency_key: dependency_key,
            )
          end

          let!(:older_compiled_package) do
            Models::CompiledPackage.make(
              package: example_package,
              stemcell_version: '1.1',
              stemcell_os: example_stemcell.os,
              dependency_key: dependency_key,
            )
          end

          it 'will return the newest matching compiled package' do
            result = compiled_package_finder.find_compiled_package(
              package: example_package,
              stemcell: example_stemcell,
              dependency_key: dependency_key,
              cache_key: cache_key,
              event_log_stage: event_log_stage,
            )
            expect(result).to eq(newer_compiled_package)
          end
        end

        context 'and there is no compiled package for the given stemcell line' do
          context 'and the global package cache is enabled' do
            let!(:compiled_package) { Models::CompiledPackage.make }

            before do
              allow(Config).to receive(:use_compiled_package_cache?).and_return(true)
              allow(BlobUtil).to receive(:fetch_from_global_cache).and_return(compiled_package)
            end

            context 'and it exists in the global cache' do
              let!(:compiled_package) { Models::CompiledPackage.make }

              before do
                allow(BlobUtil).to receive(:exists_in_global_cache?).and_return(true)
                allow(event_log_stage).to receive(:advance_and_track).and_yield
              end

              it 'returns the compiled package' do
                result = compiled_package_finder.find_compiled_package(
                  package: example_package,
                  stemcell: example_stemcell,
                  dependency_key: dependency_key,
                  cache_key: cache_key,
                  event_log_stage: event_log_stage,
                )
                expect(result).to eq(compiled_package)

                expect(event_log_stage).to have_received(:advance_and_track)
                  .with("Downloading '#{example_package.desc}' from global cache")
                expect(BlobUtil).to have_received(:exists_in_global_cache?).with(example_package, cache_key)
                expect(BlobUtil).to have_received(:fetch_from_global_cache)
                  .with(example_package, example_stemcell, cache_key, dependency_key)
              end
            end

            context 'and it does not exist in the global cache' do
              before do
                allow(BlobUtil).to receive(:exists_in_global_cache?).and_return(false)
              end

              it 'returns nil' do
                result = compiled_package_finder.find_compiled_package(
                  package: example_package,
                  stemcell: example_stemcell,
                  dependency_key: dependency_key,
                  cache_key: cache_key,
                  event_log_stage: event_log_stage,
                )
                expect(result).to be_nil

                expect(BlobUtil).to have_received(:exists_in_global_cache?).with(example_package, cache_key)
                expect(BlobUtil).to_not have_received(:fetch_from_global_cache)
              end
            end
          end

          context 'and the global cache is not enabled' do
            before do
              allow(Config).to receive(:use_compiled_package_cache?).and_return(false)
            end

            it 'returns nil' do
              result = compiled_package_finder.find_compiled_package(
                package: example_package,
                stemcell: example_stemcell,
                dependency_key: dependency_key,
                cache_key: cache_key,
                event_log_stage: event_log_stage,
              )
              expect(result).to be_nil
            end
          end
        end
      end

      context 'if the given package has source' do
        let(:example_package) { Models::Package.make(release: example_release_model, blobstore_id: 'blobstore-id') }

        context 'and there is a compiled package that matches the stemcell version exactly' do
          let!(:compiled_package) do
            Models::CompiledPackage.make(
              package: example_package,
              stemcell_version: example_stemcell.version,
              stemcell_os: example_stemcell.os,
              dependency_key: dependency_key,
            )
          end

          it 'returns the compiled package' do
            result = compiled_package_finder.find_compiled_package(
              package: example_package,
              stemcell: example_stemcell,
              dependency_key: dependency_key,
              cache_key: cache_key,
              event_log_stage: event_log_stage,
            )
            expect(result).to eq(compiled_package)
          end
        end

        context 'and there is no compiled package that matches the stemcell version exactly' do
          let!(:newer_compiled_package) do
            Models::CompiledPackage.make(
              package: example_package,
              stemcell_version: '1.3',
              stemcell_os: example_stemcell.os,
              dependency_key: dependency_key,
            )
          end

          let!(:older_compiled_package) do
            Models::CompiledPackage.make(
              package: example_package,
              stemcell_version: '1.1',
              stemcell_os: example_stemcell.os,
              dependency_key: dependency_key,
            )
          end

          context 'and the global package cache is enabled' do
            let!(:compiled_package) { Models::CompiledPackage.make }

            before do
              allow(Config).to receive(:use_compiled_package_cache?).and_return(true)
              allow(BlobUtil).to receive(:fetch_from_global_cache).and_return(compiled_package)
            end

            context 'and it exists in the global cache' do
              let!(:compiled_package) { Models::CompiledPackage.make }

              before do
                allow(BlobUtil).to receive(:exists_in_global_cache?).and_return(true)
                allow(event_log_stage).to receive(:advance_and_track).and_yield
              end

              it 'returns the compiled package' do
                result = compiled_package_finder.find_compiled_package(
                  package: example_package,
                  stemcell: example_stemcell,
                  dependency_key: dependency_key,
                  cache_key: cache_key,
                  event_log_stage: event_log_stage,
                )
                expect(result).to eq(compiled_package)

                expect(event_log_stage).to have_received(:advance_and_track)
                  .with("Downloading '#{example_package.desc}' from global cache")
                expect(BlobUtil).to have_received(:exists_in_global_cache?).with(example_package, cache_key)
                expect(BlobUtil).to have_received(:fetch_from_global_cache)
                  .with(example_package, example_stemcell, cache_key, dependency_key)
              end
            end

            context 'and it does not exist in the global cache' do
              before do
                allow(BlobUtil).to receive(:exists_in_global_cache?).and_return(false)
              end

              it 'returns nil' do
                result = compiled_package_finder.find_compiled_package(
                  package: example_package,
                  stemcell: example_stemcell,
                  dependency_key: dependency_key,
                  cache_key: cache_key,
                  event_log_stage: event_log_stage,
                )
                expect(result).to be_nil

                expect(BlobUtil).to have_received(:exists_in_global_cache?).with(example_package, cache_key)
                expect(BlobUtil).to_not have_received(:fetch_from_global_cache)
              end
            end
          end

          context 'and the global cache is not enabled' do
            before do
              allow(Config).to receive(:use_compiled_package_cache?).and_return(false)
            end

            it 'returns nil' do
              result = compiled_package_finder.find_compiled_package(
                package: example_package,
                stemcell: example_stemcell,
                dependency_key: dependency_key,
                cache_key: cache_key,
                event_log_stage: event_log_stage,
              )
              expect(result).to be_nil
            end
          end
        end
      end

      context 'if given a release with exported_from' do
        let(:example_package) { Models::Package.make(release: example_release_model, blobstore_id: nil, sha1: nil) }
        let(:exported_from) { [DeploymentPlan::Stemcell.make(os: example_stemcell.os, version: '1.0')] }

        context 'when there is a compiled package for exported_from stemcell' do
          let!(:expected_compile_package) do
            Models::CompiledPackage.make(
              package: example_package,
              stemcell_version: '1.0',
              stemcell_os: example_stemcell.os,
              dependency_key: dependency_key,
            )
          end

          before do
            # the decoy package
            Models::CompiledPackage.make(
              package: example_package,
              stemcell_version: '1.2',
              stemcell_os: example_stemcell.os,
              dependency_key: dependency_key,
            )
          end

          it 'returns the package compiled on the exported_from stemcell' do
            compiled_package = compiled_package_finder.find_compiled_package(
              package: example_package,
              stemcell: example_stemcell,
              exported_from: exported_from,
              dependency_key: dependency_key,
              cache_key: cache_key,
              event_log_stage: event_log_stage,
            )
            expect(compiled_package).to eq(expected_compile_package)
          end
        end

        context 'when there are multiple exported_froms' do
          let(:second_stemcell) do
            DeploymentPlan::Stemcell.make(os: 'ubuntu-another', version: '1.2')
          end

          let(:exported_from) do
            [
              DeploymentPlan::Stemcell.make(os: example_stemcell.os, version: '1.0'),
              second_stemcell,
            ]
          end

          let!(:expected_compile_package) do
            Models::CompiledPackage.make(
              package: example_package,
              stemcell_version: '1.2',
              stemcell_os: second_stemcell.os,
              dependency_key: dependency_key,
            )
          end

          before do
            # the decoy package
            Models::CompiledPackage.make(
              package: example_package,
              stemcell_version: '1.2',
              stemcell_os: example_stemcell.os,
              dependency_key: dependency_key,
            )
          end

          it 'finds an exact match for the second exported from' do
            compiled_package = compiled_package_finder.find_compiled_package(
              package: example_package,
              stemcell: second_stemcell,
              exported_from: exported_from,
              dependency_key: dependency_key,
              cache_key: cache_key,
              event_log_stage: event_log_stage,
            )
            expect(compiled_package).to eq(expected_compile_package)
          end
        end
      end
    end
  end
end
