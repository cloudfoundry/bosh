require 'spec_helper'

module Bosh::Director
  describe CompiledPackageRequirementGenerator do
    include Support::StemcellHelpers

    describe '#generate!' do
      subject(:generator) { described_class.new(per_spec_logger, event_log, compiled_package_finder) }

      let(:release_version_model) { FactoryBot.create(:models_release_version) }
      let(:release_version) do
        instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', model: release_version_model, exported_from: [])
      end

      let(:instance_group) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', use_compiled_package: nil) }
      let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job', release: release_version) }

      let(:package_a) do
        FactoryBot.create(:models_package, name: 'package_a', dependency_set_json: ['package_b'].to_json)
      end
      let(:package_b) do
        FactoryBot.create(:models_package,
          name: 'package_b',
          version: '2',
          dependency_set_json: ['package_c'].to_json,
        )
      end
      let(:package_c) do
        FactoryBot.create(:models_package, name: 'package_c', version: '3')
      end

      let(:stemcell) { make_stemcell(operating_system: 'chrome-os', version: 'latest') }
      let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }
      let(:compiled_package_finder) { DeploymentPlan::CompiledPackageFinder.new(per_spec_logger) }

      let(:requirements) do
        {}
      end

      before do
        release_version_model.packages << package_a
        release_version_model.packages << package_b
        release_version_model.packages << package_c
      end

      context 'when existing compiled packages do not exist' do
        context 'when the dependency is linear' do
          it 'correctly adds dependencies' do
            expect(::Digest::SHA1).to receive(:hexdigest).and_return(
              'package-cache-key-a',
              'package-cache-key-b',
              'package-cache-key-c',
            )
            generator.generate!(requirements, instance_group, job, package_a, stemcell)

            expect(requirements.size).to eq(3)

            requirements.each_value do |requirement|
              expect(requirement.instance_groups).to eq([instance_group])
            end

            requirement_a = requirements[[package_a.id, "#{stemcell.os}/#{stemcell.version}"]]
            requirement_b = requirements[[package_b.id, "#{stemcell.os}/#{stemcell.version}"]]
            requirement_c = requirements[[package_c.id, "#{stemcell.os}/#{stemcell.version}"]]

            expect(requirement_a.dependencies).to eq([requirement_b])
            expect(requirement_b.dependencies).to eq([requirement_c])
            expect(requirement_c.dependencies).to eq([])

            expect(requirement_a.cache_key).to eq('package-cache-key-a')
            expect(requirement_b.cache_key).to eq('package-cache-key-b')
            expect(requirement_c.cache_key).to eq('package-cache-key-c')

            expect(requirement_a.dependency_key).to eq('[["package_b","2",[["package_c","3"]]]]')
            expect(requirement_b.dependency_key).to eq('[["package_c","3"]]')
            expect(requirement_c.dependency_key).to eq('[]')
          end
        end

        context 'when two packages share a dependency' do
          let(:package_d) { FactoryBot.create(:models_package, name: 'package_d', version: '9') }

          before do
            release_version_model.packages << package_d
          end

          it 'correctly adds dependencies' do
            expect(::Digest::SHA1).to receive(:hexdigest).and_return(
              'package-cache-key-a',
              'package-cache-key-b',
              'package-cache-key-c',
              'package-cache-key-d',
            )

            package_a.dependency_set_json = %w[package_b package_c].to_json
            package_b.dependency_set_json = ['package_d'].to_json
            package_c.dependency_set_json = ['package_d'].to_json

            generator.generate!(requirements, instance_group, job, package_a, stemcell)

            expect(requirements.size).to eq(4)

            requirements.each_value do |requirement|
              expect(requirement.instance_groups).to eq([instance_group])
            end

            requirement_a = requirements[[package_a.id, "#{stemcell.os}/#{stemcell.version}"]]
            requirement_b = requirements[[package_b.id, "#{stemcell.os}/#{stemcell.version}"]]
            requirement_c = requirements[[package_c.id, "#{stemcell.os}/#{stemcell.version}"]]
            requirement_d = requirements[[package_d.id, "#{stemcell.os}/#{stemcell.version}"]]

            expect(requirement_a.dependencies).to eq([requirement_b, requirement_c])
            expect(requirement_b.dependencies).to eq([requirement_d])
            expect(requirement_c.dependencies).to eq([requirement_d])
            expect(requirement_d.dependencies).to eq([])

            expect(requirement_a.cache_key).to eq('package-cache-key-a')
            expect(requirement_b.cache_key).to eq('package-cache-key-b')
            expect(requirement_c.cache_key).to eq('package-cache-key-d')
            expect(requirement_d.cache_key).to eq('package-cache-key-c')

            expect(requirement_a.dependency_key).to eq(
              '[["package_b","2",[["package_d","9"]]],["package_c","3",[["package_d","9"]]]]',
            )
            expect(requirement_b.dependency_key).to eq('[["package_d","9"]]')
            expect(requirement_c.dependency_key).to eq('[["package_d","9"]]')
            expect(requirement_d.dependency_key).to eq('[]')
          end
        end
      end

      context 'when existing compiled packages exist' do
        let!(:compiled_package_c) do
          FactoryBot.create(:models_compiled_package,
            package: package_c,
            stemcell_os: stemcell.os,
            stemcell_version: stemcell.version,
            dependency_key: '[]',
          )
        end

        context 'when the dependency is linear' do
          it 'correctly adds dependencies' do
            expect(::Digest::SHA1).to receive(:hexdigest).and_return(
              'package-cache-key-a',
              'package-cache-key-b',
              'package-cache-key-c',
            )

            generator.generate!(requirements, instance_group, job, package_a, stemcell)

            expect(requirements.size).to eq(3)
            requirements.each_value do |requirement|
              expect(requirement.instance_groups).to eq([instance_group])
            end

            requirement_a = requirements[[package_a.id, "#{stemcell.os}/#{stemcell.version}"]]
            requirement_b = requirements[[package_b.id, "#{stemcell.os}/#{stemcell.version}"]]
            requirement_c = requirements[[package_c.id, "#{stemcell.os}/#{stemcell.version}"]]

            expect(requirement_a.dependencies).to eq([requirement_b])
            expect(requirement_b.dependencies).to eq([requirement_c])
            expect(requirement_c.dependencies).to eq([])

            expect(requirement_a.cache_key).to eq('package-cache-key-a')
            expect(requirement_b.cache_key).to eq('package-cache-key-b')
            expect(requirement_c.cache_key).to eq('package-cache-key-c')

            expect(requirement_a.dependency_key).to eq('[["package_b","2",[["package_c","3"]]]]')
            expect(requirement_b.dependency_key).to eq('[["package_c","3"]]')
            expect(requirement_c.dependency_key).to eq('[]')
          end
        end

        context 'when two packages share a dependency' do
          let(:package_d) { FactoryBot.create(:models_package, name: 'package_d', version: '6') }
          let!(:compiled_package_c) do
            FactoryBot.create(:models_compiled_package,
              package: package_c,
              stemcell_os: stemcell.os,
              stemcell_version: stemcell.version,
              dependency_key: [%w[package_d 6]].to_json,
            )
          end

          before do
            release_version_model.packages << package_d
          end

          it 'correctly adds dependencies' do
            expect(::Digest::SHA1).to receive(:hexdigest).and_return(
              'package-cache-key-a',
              'package-cache-key-b',
              'package-cache-key-c',
              'package-cache-key-d',
            )

            package_a.dependency_set_json = %w[package_b package_c].to_json
            package_b.dependency_set_json = ['package_d'].to_json
            package_c.dependency_set_json = ['package_d'].to_json

            generator.generate!(requirements, instance_group, job, package_a, stemcell)

            expect(requirements.size).to eq(4)
            requirements.each_value do |requirement|
              expect(requirement.instance_groups).to eq([instance_group])
            end

            requirement_a = requirements[[package_a.id, "#{stemcell.os}/#{stemcell.version}"]]
            requirement_b = requirements[[package_b.id, "#{stemcell.os}/#{stemcell.version}"]]
            requirement_c = requirements[[package_c.id, "#{stemcell.os}/#{stemcell.version}"]]
            requirement_d = requirements[[package_d.id, "#{stemcell.os}/#{stemcell.version}"]]

            expect(requirement_a.dependencies).to eq([requirement_b, requirement_c])
            expect(requirement_b.dependencies).to eq([requirement_d])
            expect(requirement_c.dependencies).to eq([requirement_d])
            expect(requirement_d.dependencies).to eq([])

            expect(requirement_a.cache_key).to eq('package-cache-key-a')
            expect(requirement_b.cache_key).to eq('package-cache-key-b')
            expect(requirement_c.cache_key).to eq('package-cache-key-d')
            expect(requirement_d.cache_key).to eq('package-cache-key-c')

            expect(requirement_a.dependency_key).to eq(
              '[["package_b","2",[["package_d","6"]]],["package_c","3",[["package_d","6"]]]]',
            )
            expect(requirement_b.dependency_key).to eq('[["package_d","6"]]')
            expect(requirement_c.dependency_key).to eq('[["package_d","6"]]')
            expect(requirement_d.dependency_key).to eq('[]')
          end
        end
      end

      describe 'logging' do
        it 'logs at each step of dependency resolution' do
          allow(per_spec_logger).to receive(:info)
          expect(per_spec_logger).to receive(:info).with(
            "Checking whether package '#{package_a.desc}' needs to be compiled for stemcell '#{stemcell.desc}'",
          ).ordered
          expect(per_spec_logger).to receive(:info).with("Processing package '#{package_a.desc}' dependencies").ordered
          expect(per_spec_logger).to receive(:info).with(
            "Package '#{package_a.desc}' depends on package '#{package_b.desc}'",
          ).ordered

          expect(per_spec_logger).to receive(:info).with(
            "Checking whether package '#{package_b.desc}' needs to be compiled for stemcell '#{stemcell.desc}'",
          ).ordered
          expect(per_spec_logger).to receive(:info).with("Processing package '#{package_b.desc}' dependencies").ordered

          generator.generate!(requirements, instance_group, job, package_a, stemcell)
        end
      end
    end
  end
end
