require 'spec_helper'
require 'bosh/director/compile_task_generator'

module Bosh::Director
  describe CompileTaskGenerator do
    include Support::StemcellHelpers

    describe '#generate!' do
      subject(:generator) { described_class.new(logger, event_log) }

      let(:release_version_model) { Models::ReleaseVersion.make }
      let(:release_version) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', model: release_version_model) }

      let(:job) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', use_compiled_package: nil) }
      let(:template) { instance_double('Bosh::Director::DeploymentPlan::Job', release: release_version) }

      let(:package_a) { Bosh::Director::Models::Package.make(name: 'package_a', dependency_set_json: ['package_b'].to_json) }
      let(:package_b) { Bosh::Director::Models::Package.make(name: 'package_b', version: '2', dependency_set_json: ['package_c'].to_json) }
      let(:package_c) { Bosh::Director::Models::Package.make(name: 'package_c', version: '3') }

      let(:stemcell) { make_stemcell({operating_system: 'chrome-os', version: 'latest'}) }
      let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

      let(:compile_tasks) { {} }

      before do
        release_version_model.packages << package_a
        release_version_model.packages << package_b
        release_version_model.packages << package_c
      end

      context 'when existing compiled packages do not exist' do
        context 'when the dependency is linear' do
          it 'correctly adds dependencies' do
            expect(Digest::SHA1).to receive(:hexdigest).and_return('package-cache-key-a', 'package-cache-key-b', 'package-cache-key-c')

            generator.generate!(compile_tasks, job, template, package_a, stemcell)

            expect(compile_tasks.size).to eq(3)

            compile_tasks.each_value do |task|
              expect(task.jobs).to eq([job])
            end

            task_a = compile_tasks[[package_a.id, stemcell.model.id]]
            task_b = compile_tasks[[package_b.id, stemcell.model.id]]
            task_c = compile_tasks[[package_c.id, stemcell.model.id]]

            expect(task_a.dependencies).to eq([task_b])
            expect(task_b.dependencies).to eq([task_c])
            expect(task_c.dependencies).to eq([])

            expect(task_a.cache_key).to eq('package-cache-key-a')
            expect(task_b.cache_key).to eq('package-cache-key-b')
            expect(task_c.cache_key).to eq('package-cache-key-c')

            expect(task_a.dependency_key).to eq('[["package_b","2",[["package_c","3"]]]]')
            expect(task_b.dependency_key).to eq('[["package_c","3"]]')
            expect(task_c.dependency_key).to eq('[]')
          end
        end

        context 'when two packages share a dependency' do
          let(:package_d) { Bosh::Director::Models::Package.make(name: 'package_d', version: '9') }

          before do
            release_version_model.packages << package_d
          end

          it 'correctly adds dependencies' do
            expect(Digest::SHA1).to receive(:hexdigest).and_return('package-cache-key-a', 'package-cache-key-b', 'package-cache-key-c', 'package-cache-key-d')

            package_a.dependency_set_json = ['package_b', 'package_c'].to_json
            package_b.dependency_set_json = ['package_d'].to_json
            package_c.dependency_set_json = ['package_d'].to_json

            generator.generate!(compile_tasks, job, template, package_a, stemcell)

            expect(compile_tasks.size).to eq(4)

            compile_tasks.each_value do |task|
              expect(task.jobs).to eq([job])
            end

            task_a = compile_tasks[[package_a.id, stemcell.model.id]]
            task_b = compile_tasks[[package_b.id, stemcell.model.id]]
            task_c = compile_tasks[[package_c.id, stemcell.model.id]]
            task_d = compile_tasks[[package_d.id, stemcell.model.id]]

            expect(task_a.dependencies).to eq([task_b, task_c])
            expect(task_b.dependencies).to eq([task_d])
            expect(task_c.dependencies).to eq([task_d])
            expect(task_d.dependencies).to eq([])

            expect(task_a.cache_key).to eq('package-cache-key-a')
            expect(task_b.cache_key).to eq('package-cache-key-b')
            expect(task_c.cache_key).to eq('package-cache-key-d')
            expect(task_d.cache_key).to eq('package-cache-key-c')

            expect(task_a.dependency_key).to eq('[["package_b","2",[["package_d","9"]]],["package_c","3",[["package_d","9"]]]]')
            expect(task_b.dependency_key).to eq('[["package_d","9"]]')
            expect(task_c.dependency_key).to eq('[["package_d","9"]]')
            expect(task_d.dependency_key).to eq('[]')
          end
        end
      end

      context 'when existing compiled packages exist' do
        let!(:compiled_package_c) { Models::CompiledPackage.make(package: package_c, stemcell_os: stemcell.os, stemcell_version: stemcell.version, dependency_key: '[]') }

        context 'when the dependency is linear' do
          it 'correctly adds dependencies' do
            expect(Digest::SHA1).to receive(:hexdigest).and_return('package-cache-key-a', 'package-cache-key-b', 'package-cache-key-c')

            generator.generate!(compile_tasks, job, template, package_a, stemcell)

            expect(compile_tasks.size).to eq(3)
            compile_tasks.each_value do |task|
              expect(task.jobs).to eq([job])
            end

            task_a = compile_tasks[[package_a.id, stemcell.model.id]]
            task_b = compile_tasks[[package_b.id, stemcell.model.id]]
            task_c = compile_tasks[[package_c.id, stemcell.model.id]]

            expect(task_a.dependencies).to eq([task_b])
            expect(task_b.dependencies).to eq([task_c])
            expect(task_c.dependencies).to eq([])

            expect(task_c.compiled_package).to eq(compiled_package_c)

            expect(task_a.cache_key).to eq('package-cache-key-a')
            expect(task_b.cache_key).to eq('package-cache-key-b')
            expect(task_c.cache_key).to eq('package-cache-key-c')

            expect(task_a.dependency_key).to eq('[["package_b","2",[["package_c","3"]]]]')
            expect(task_b.dependency_key).to eq('[["package_c","3"]]')
            expect(task_c.dependency_key).to eq('[]')
          end
        end

        context 'when two packages share a dependency' do
          let(:package_d) { Bosh::Director::Models::Package.make(name: 'package_d', version: '6') }
          let!(:compiled_package_c) { Models::CompiledPackage.make(package: package_c, stemcell_os: stemcell.os, stemcell_version: stemcell.version, dependency_key: [['package_d', '6']].to_json) }

          before do
            release_version_model.packages << package_d
          end

          it 'correctly adds dependencies' do
            expect(Digest::SHA1).to receive(:hexdigest).and_return('package-cache-key-a', 'package-cache-key-b', 'package-cache-key-c', 'package-cache-key-d')

            package_a.dependency_set_json = ['package_b', 'package_c'].to_json
            package_b.dependency_set_json = ['package_d'].to_json
            package_c.dependency_set_json = ['package_d'].to_json

            generator.generate!(compile_tasks, job, template, package_a, stemcell)

            expect(compile_tasks.size).to eq(4)
            compile_tasks.each_value do |task|
              expect(task.jobs).to eq([job])
            end

            task_a = compile_tasks[[package_a.id, stemcell.model.id]]
            task_b = compile_tasks[[package_b.id, stemcell.model.id]]
            task_c = compile_tasks[[package_c.id, stemcell.model.id]]
            task_d = compile_tasks[[package_d.id, stemcell.model.id]]

            expect(task_a.dependencies).to eq([task_b, task_c])
            expect(task_b.dependencies).to eq([task_d])
            expect(task_c.dependencies).to eq([task_d])
            expect(task_d.dependencies).to eq([])

            expect(task_c.compiled_package).to eq(compiled_package_c)

            expect(task_a.cache_key).to eq('package-cache-key-a')
            expect(task_b.cache_key).to eq('package-cache-key-b')
            expect(task_c.cache_key).to eq('package-cache-key-d')
            expect(task_d.cache_key).to eq('package-cache-key-c')

            expect(task_a.dependency_key).to eq('[["package_b","2",[["package_d","6"]]],["package_c","3",[["package_d","6"]]]]')
            expect(task_b.dependency_key).to eq('[["package_d","6"]]')
            expect(task_c.dependency_key).to eq('[["package_d","6"]]')
            expect(task_d.dependency_key).to eq('[]')
          end
        end
      end

      describe 'logging' do
        it 'logs at each step of dependency resolution' do
          allow(logger).to receive(:info)
          expect(logger).to receive(:info).with("Checking whether package '#{package_a.desc}' needs to be compiled for stemcell '#{stemcell.model.desc}'").ordered
          expect(logger).to receive(:info).with("Processing package '#{package_a.desc}' dependencies").ordered
          expect(logger).to receive(:info).with("Package '#{package_a.desc}' depends on package '#{package_b.desc}'").ordered

          expect(logger).to receive(:info).with("Checking whether package '#{package_b.desc}' needs to be compiled for stemcell '#{stemcell.model.desc}'").ordered
          expect(logger).to receive(:info).with("Processing package '#{package_b.desc}' dependencies").ordered

          generator.generate!(compile_tasks, job, template, package_a, stemcell)
        end
      end
    end
  end
end
