require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::CompiledPackageFinder do
    include Support::StemcellHelpers

    context '#find_compiled_package' do
      let(:event_log_stage) { double('event_log_stage') }
      let(:example_release_model) { Models::Release.make }
      let(:example_stemcell) do
        FactoryBot.build(:deployment_plan_stemcell, version: '1.2')
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
        end
      end

      context 'if given a release with exported_from' do
        let(:example_package) { Models::Package.make(release: example_release_model, blobstore_id: nil, sha1: nil) }
        let(:exported_from) { [FactoryBot.build(:deployment_plan_stemcell, os: example_stemcell.os, version: '1.0')] }

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
            FactoryBot.build(:deployment_plan_stemcell, os: 'ubuntu-another', version: '1.2')
          end

          let(:exported_from) do
            [
              FactoryBot.build(:deployment_plan_stemcell, os: example_stemcell.os, version: '1.0'),
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
