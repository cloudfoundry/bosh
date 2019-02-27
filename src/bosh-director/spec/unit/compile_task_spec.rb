require 'spec_helper'

module Bosh::Director
  describe CompileTask do
    include Support::StemcellHelpers

    let(:job) { double('job').as_null_object }
    let(:precompiled_package) { nil }

    def make(package, stemcell)
      CompileTask.new(package, stemcell, job, 'fake-dependency-key', 'fake-cache-key', precompiled_package)
    end

    describe 'creation' do
      let(:package_name) { 'package_name' }
      let(:package_fingerprint) { 'fingerprint' }
      let(:stemcell_sha1) { 'sha1' }
      let(:stemcell) { double('stemcell', sha1: stemcell_sha1) }
      let(:package) { double('package', name: package_name, fingerprint: package_fingerprint) }
      let(:dep_pkg2) { double('dependent package 2', fingerprint: 'dp_fingerprint2', version: '9.2-dev', name: 'zyx') }
      let(:dep_pkg1) { double('dependent package 1', fingerprint: 'dp_fingerprint1', version: '10.1-dev', name: 'abc') }

      let(:dep_task2) { make(dep_pkg2, stemcell) }
      let(:dep_task1) { make(dep_pkg1, stemcell) }

      let(:dependent_packages) { [] }

      subject(:task) do
        CompileTask.new(package, stemcell, job, 'fake-dependency-key', 'fake-cache-key', precompiled_package)
      end

      context 'with an initial job' do
        let(:job) { double('job') }

        it 'can create' do
          expect(task.jobs).to eq([job])
        end
      end

      context 'with a compiled package' do
        let(:precompiled_package) { double('compiled_package') }

        it 'is compiled' do
          expect(task.compiled?).to eq(true)
        end
      end
    end

    describe 'compilation readiness' do
      let(:package) { Models::Package.make(name: 'foo') }
      let(:stemcell) { Models::Stemcell.make({operating_system: 'chrome-os', version: 'latest'}) }
      let(:compiled_package) { Models::CompiledPackage.make(package: package, stemcell_os: 'chrome-os', stemcell_version: 'latest') }

      it 'can tell if compiled' do
        task = make(package, stemcell)
        expect(task.ready_to_compile?).to be(true)
        expect(task.compiled?).to be(false)

        task.use_compiled_package(compiled_package)
        expect(task.compiled?).to be(true)
        expect(task.ready_to_compile?).to be(false) # Already compiled!
      end

      it 'is ready to compile when all dependencies are compiled' do
        dep1 = Models::Package.make(name: 'bar')
        dep2 = Models::Package.make(name: 'baz')

        task = make(package, stemcell)
        dep1_task = make(dep1, stemcell)
        dep2_task = make(dep2, stemcell)

        task.add_dependency(dep1_task)
        task.add_dependency(dep2_task)

        expect(task.all_dependencies_compiled?).to be(false)
        dep1_task.use_compiled_package(compiled_package)
        expect(task.all_dependencies_compiled?).to be(false)
        dep2_task.use_compiled_package(compiled_package)
        expect(task.all_dependencies_compiled?).to be(true)
        expect(task.ready_to_compile?).to be(true)
      end
    end

    describe 'adding dependencies' do
      it 'works both ways' do
        stemcell = Models::Stemcell.make
        foo = Models::Package.make(name: 'foo')
        bar = Models::Package.make(name: 'bar')
        baz = Models::Package.make(name: 'baz')

        foo_task = make(foo, stemcell)
        bar_task = make(bar, stemcell)
        baz_task = make(baz, stemcell)

        expect(foo_task.dependencies).to eq([])
        expect(bar_task.dependent_tasks).to eq([])

        foo_task.add_dependency(bar_task)
        expect(foo_task.dependencies).to eq([bar_task])
        expect(bar_task.dependent_tasks).to eq([foo_task])

        baz_task.add_dependent_task(foo_task)
        expect(baz_task.dependent_tasks).to eq([foo_task])
        expect(foo_task.dependencies).to eq([bar_task, baz_task])
      end
    end

    describe 'using compiled package' do
      let(:job) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup') }

      it 'registers compiled package with job' do
        package = Models::Package.make
        stemcell = Models::Stemcell.make

        cp = Models::CompiledPackage.make({stemcell_os: 'firefox_os', stemcell_version: '2'})
        cp2 = Models::CompiledPackage.make({stemcell_os: 'firefox_os', stemcell_version: '2'})

        task = make(package, stemcell)

        job_a = job
        job_b = instance_double('Bosh::Director::DeploymentPlan::InstanceGroup')

        expect(job_a).to receive(:use_compiled_package).with(cp)
        expect(job_b).to receive(:use_compiled_package).with(cp)

        task.use_compiled_package(cp)
        task.add_job(job_a)
        task.add_job(job_b)

        expect(task.jobs).to eq([job_a, job_b])

        expect(job_a).to receive(:use_compiled_package).with(cp2)
        expect(job_b).to receive(:use_compiled_package).with(cp2)
        task.use_compiled_package(cp2)
      end
    end

    describe 'generating dependency spec' do
      it 'generates dependency spec' do
        stemcell = Models::Stemcell.make
        foo = Models::Package.make(name: 'foo')
        bar = Models::Package.make(name: 'bar', version: '42')
        cp = Models::CompiledPackage.make(package: bar, build: 152, sha1: 'deadbeef', blobstore_id: 'deadcafe', stemcell_os: 'linux', stemcell_version: '2.6.11')

        foo_task = make(foo, stemcell)
        bar_task = make(bar, stemcell)

        foo_task.add_dependency(bar_task)

        expect {
          foo_task.dependency_spec
        }.to raise_error(DirectorError, /'bar' hasn't been compiled yet/i)

        bar_task.use_compiled_package(cp)

        expect(foo_task.dependency_spec).to eq({
            'bar' => {
                'name' => 'bar',
                'version' => '42.152',
                'sha1' => 'deadbeef',
                'blobstore_id' => 'deadcafe'
            }
        })
      end

      it "doesn't include nested dependencies" do
        stemcell = Models::Stemcell.make
        foo = Models::Package.make(name:  'foo')
        bar = Models::Package.make(name:  'bar', :version => '42')
        baz = Models::Package.make(name:  'baz', :version => '17')

        cp_bar = Models::CompiledPackage.make(package: bar, build: 152, sha1: 'deadbeef', blobstore_id: 'deadcafe', stemcell_os: 'chrome-os', stemcell_version: 'latest')

        foo_task = make(foo, stemcell)
        bar_task = make(bar, stemcell)
        baz_task = make(baz, stemcell)

        foo_task.add_dependency(bar_task)
        bar_task.add_dependency(baz_task)

        expect(foo_task.dependencies).to eq([bar_task]) # only includes immediate deps!
        expect(bar_task.dependencies).to eq([baz_task])

        bar_task.use_compiled_package(cp_bar)

        expect(foo_task.dependency_spec).to eq({
            'bar' => {
                'name' => 'bar',
                'version' => '42.152',
                'sha1' => 'deadbeef',
                'blobstore_id' => 'deadcafe'
            }
        })
      end
    end
  end
end
