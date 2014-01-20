require 'spec_helper'
require 'bosh/director/compile_task_generator'

module Bosh::Director
  describe CompileTaskGenerator do
    describe '#generate!' do
      subject(:generator) { described_class.new(logger, event_log) }

      let(:release_version_model) { instance_double('Bosh::Director::Models::ReleaseVersion', package_dependency_key: 'some-dependency-key', package_cache_key: 'some-package-cache-key') }
      let(:release_version) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', model: release_version_model) }

      let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job', use_compiled_package: nil) }
      let(:template) { instance_double('Bosh::Director::DeploymentPlan::Template', release: release_version) }

      let(:package_a) { Bosh::Director::Models::Package.make(name: 'package_a') }
      let(:package_b) { Bosh::Director::Models::Package.make(name: 'package_b') }
      let(:package_c) { Bosh::Director::Models::Package.make(name: 'package_c') }

      let(:stemcell) { Bosh::Director::Models::Stemcell.make }
      let(:logger) { instance_double('Logger', info: nil) }
      let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

      let(:compile_tasks) { {} }

      context 'when existing compiled packages do not exist' do
        context 'when the dependency is linear' do
          before do
            allow(release_version_model).to receive(:dependencies).with('package_a').and_return([package_b])
            allow(release_version_model).to receive(:dependencies).with('package_b').and_return([package_c])
            allow(release_version_model).to receive(:dependencies).with('package_c').and_return([])
          end

          it 'correctly adds dependencies' do
            generator.generate!(compile_tasks, job, template, package_a, stemcell)

            expect(compile_tasks.size).to eq(3)
            compile_tasks.each_value do |task|
              expect(task.jobs).to eq([job])
            end

            task_a = compile_tasks[[package_a.id, stemcell.id]]
            task_b = compile_tasks[[package_b.id, stemcell.id]]
            task_c = compile_tasks[[package_c.id, stemcell.id]]

            expect(task_a.dependencies).to eq([task_b])
            expect(task_b.dependencies).to eq([task_c])
            expect(task_c.dependencies).to eq([])
          end
        end

        context 'when two packages share a dependency' do
          let(:package_d) { Bosh::Director::Models::Package.make(name: 'package_d') }

          before do
            allow(release_version_model).to receive(:dependencies).with('package_a').and_return([package_b, package_c])
            allow(release_version_model).to receive(:dependencies).with('package_b').and_return([package_d])
            allow(release_version_model).to receive(:dependencies).with('package_c').and_return([package_d])
            allow(release_version_model).to receive(:dependencies).with('package_d').and_return([])
          end

          it 'correctly adds dependencies' do
            generator.generate!(compile_tasks, job, template, package_a, stemcell)

            expect(compile_tasks.size).to eq(4)
            compile_tasks.each_value do |task|
              expect(task.jobs).to eq([job])
            end

            task_a = compile_tasks[[package_a.id, stemcell.id]]
            task_b = compile_tasks[[package_b.id, stemcell.id]]
            task_c = compile_tasks[[package_c.id, stemcell.id]]
            task_d = compile_tasks[[package_d.id, stemcell.id]]

            expect(task_a.dependencies).to eq([task_b, task_c])
            expect(task_b.dependencies).to eq([task_d])
            expect(task_c.dependencies).to eq([task_d])
            expect(task_d.dependencies).to eq([])
          end
        end
      end

      context 'when existing compiled packages exist' do
        let!(:compiled_package_c) { Models::CompiledPackage.make(package: package_c, stemcell: stemcell, dependency_key: 'some-dependency-key') }

        context 'when the dependency is linear' do
          before do
            allow(release_version_model).to receive(:dependencies).with('package_a').and_return([package_b])
            allow(release_version_model).to receive(:dependencies).with('package_b').and_return([package_c])
            allow(release_version_model).to receive(:dependencies).with('package_c').and_return([])
          end

          it 'correctly adds dependencies' do
            generator.generate!(compile_tasks, job, template, package_a, stemcell)

            expect(compile_tasks.size).to eq(3)
            compile_tasks.each_value do |task|
              expect(task.jobs).to eq([job])
            end

            task_a = compile_tasks[[package_a.id, stemcell.id]]
            task_b = compile_tasks[[package_b.id, stemcell.id]]
            task_c = compile_tasks[[package_c.id, stemcell.id]]

            expect(task_a.dependencies).to eq([task_b])
            expect(task_b.dependencies).to eq([task_c])

            expect(task_c.compiled_package).to eq(compiled_package_c)
            expect(task_c.dependencies).to eq([])
          end
        end

        context 'when two packages share a dependency' do
          let(:package_d) { Bosh::Director::Models::Package.make(name: 'package_d') }

          before do
            allow(release_version_model).to receive(:dependencies).with('package_a').and_return([package_b, package_c])
            allow(release_version_model).to receive(:dependencies).with('package_b').and_return([package_d])
            allow(release_version_model).to receive(:dependencies).with('package_c').and_return([package_d])
            allow(release_version_model).to receive(:dependencies).with('package_d').and_return([])
          end

          it 'correctly adds dependencies' do
            generator.generate!(compile_tasks, job, template, package_a, stemcell)

            expect(compile_tasks.size).to eq(4)
            compile_tasks.each_value do |task|
              expect(task.jobs).to eq([job])
            end

            task_a = compile_tasks[[package_a.id, stemcell.id]]
            task_b = compile_tasks[[package_b.id, stemcell.id]]
            task_c = compile_tasks[[package_c.id, stemcell.id]]
            task_d = compile_tasks[[package_d.id, stemcell.id]]

            expect(task_a.dependencies).to eq([task_b, task_c])
            expect(task_b.dependencies).to eq([task_d])

            expect(task_c.compiled_package).to eq(compiled_package_c)
            expect(task_c.dependencies).to eq([task_d])
            expect(task_d.dependencies).to eq([])
          end
        end
      end

      describe 'logging' do
        before do
          allow(release_version_model).to receive(:dependencies).with('package_a').and_return([package_b])
          allow(release_version_model).to receive(:dependencies).with('package_b').and_return([])
        end

        it 'logs at each step of dependency resolution' do
          expect(logger).to receive(:info).with("Checking whether package `#{package_a.desc}' needs to be compiled for stemcell `#{stemcell.desc}'").ordered
          expect(logger).to receive(:info).with("Processing package `#{package_a.desc}' dependencies").ordered
          expect(logger).to receive(:info).with("Package `#{package_a.desc}' depends on package `#{package_b.desc}'").ordered

          expect(logger).to receive(:info).with("Checking whether package `#{package_b.desc}' needs to be compiled for stemcell `#{stemcell.desc}'").ordered
          expect(logger).to receive(:info).with("Processing package `#{package_b.desc}' dependencies").ordered

          generator.generate!(compile_tasks, job, template, package_a, stemcell)
        end
      end
    end
  end
end
