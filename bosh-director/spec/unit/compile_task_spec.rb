require 'spec_helper'

module Bosh::Director
  describe CompileTask do
    let(:job) { double('job').as_null_object }

    def make(package, stemcell)
      CompileTask.new(package, stemcell, job, 'fake-dependency-key', 'fake-cache-key')
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
        CompileTask.new(package, stemcell, job, 'fake-dependency-key', 'fake-cache-key')
      end

      context 'with an initial job' do
        let(:job) { double('job') }

        it 'can create' do
          task.jobs.should == [job]
        end
      end
    end

    describe 'compilation readiness' do
      it 'can tell if compiled' do
        package = Models::Package.make(name:  'foo')
        stemcell = Models::Stemcell.make
        compiled_package = Models::CompiledPackage.make(:package => package)

        task = make(package, stemcell)
        task.ready_to_compile?.should be(true)
        task.compiled?.should be(false)

        task.use_compiled_package(compiled_package)
        task.compiled?.should be(true)
        task.ready_to_compile?.should be(false) # Already compiled!
      end

      it 'is ready to compile when all dependencies are compiled' do
        package = Models::Package.make(name: 'foo')
        stemcell = Models::Stemcell.make
        compiled_package = Models::CompiledPackage.make

        dep1 = Models::Package.make(name: 'bar')
        dep2 = Models::Package.make(name: 'baz')

        task = make(package, stemcell)
        dep1_task = make(dep1, stemcell)
        dep2_task = make(dep2, stemcell)

        task.add_dependency(dep1_task)
        task.add_dependency(dep2_task)

        task.all_dependencies_compiled?.should be(false)
        dep1_task.use_compiled_package(compiled_package)
        task.all_dependencies_compiled?.should be(false)
        dep2_task.use_compiled_package(compiled_package)
        task.all_dependencies_compiled?.should be(true)
        task.ready_to_compile?.should be(true)
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

        foo_task.dependencies.should == []
        bar_task.dependent_tasks.should == []

        foo_task.add_dependency(bar_task)
        foo_task.dependencies.should == [bar_task]
        bar_task.dependent_tasks.should == [foo_task]

        baz_task.add_dependent_task(foo_task)
        baz_task.dependent_tasks.should == [foo_task]
        foo_task.dependencies.should == [bar_task, baz_task]
      end
    end

    describe 'using compiled package' do
      let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job') }

      it 'registers compiled package with job' do
        package = Models::Package.make
        stemcell = Models::Stemcell.make

        cp = Models::CompiledPackage.make
        cp2 = Models::CompiledPackage.make

        task = make(package, stemcell)

        job_a = job
        job_b = instance_double('Bosh::Director::DeploymentPlan::Job')

        job_a.should_receive(:use_compiled_package).with(cp)
        job_b.should_receive(:use_compiled_package).with(cp)

        task.use_compiled_package(cp)
        task.add_job(job_a)
        task.add_job(job_b)

        task.jobs.should == [job_a, job_b]

        job_a.should_receive(:use_compiled_package).with(cp2)
        job_b.should_receive(:use_compiled_package).with(cp2)
        task.use_compiled_package(cp2)
      end
    end

    describe 'generating dependency spec' do
      it 'generates dependency spec' do
        stemcell = Models::Stemcell.make
        foo = Models::Package.make(name: 'foo')
        bar = Models::Package.make(name: 'bar', version: '42')
        cp = Models::CompiledPackage.make(package: bar, build: 152, sha1: 'deadbeef', blobstore_id: 'deadcafe')

        foo_task = make(foo, stemcell)
        bar_task = make(bar, stemcell)

        foo_task.add_dependency(bar_task)

        expect {
          foo_task.dependency_spec
        }.to raise_error(DirectorError, /`bar' hasn't been compiled yet/i)

        bar_task.use_compiled_package(cp)

        foo_task.dependency_spec.should == {
            'bar' => {
                'name' => 'bar',
                'version' => '42.152',
                'sha1' => 'deadbeef',
                'blobstore_id' => 'deadcafe'
            }
        }
      end

      it "doesn't include nested dependencies" do
        stemcell = Models::Stemcell.make
        foo = Models::Package.make(name:  'foo')
        bar = Models::Package.make(name:  'bar', :version => '42')
        baz = Models::Package.make(name:  'baz', :version => '17')

        cp_bar = Models::CompiledPackage.make(package: bar, build: 152, sha1: 'deadbeef', blobstore_id: 'deadcafe')

        cp_baz = Models::CompiledPackage.make(package: baz, build: 335, sha1: 'baddead', blobstore_id: 'deadbad')

        foo_task = make(foo, stemcell)
        bar_task = make(bar, stemcell)
        baz_task = make(baz, stemcell)

        foo_task.add_dependency(bar_task)
        bar_task.add_dependency(baz_task)

        foo_task.dependencies.should == [bar_task] # only includes immediate deps!
        bar_task.dependencies.should == [baz_task]

        bar_task.use_compiled_package(cp_bar)

        foo_task.dependency_spec.should == {
            'bar' => {
                'name' => 'bar',
                'version' => '42.152',
                'sha1' => 'deadbeef',
                'blobstore_id' => 'deadcafe'
            }
        }
      end
    end

    describe '#find_compiled_package' do
      let(:event_log) { double("event_log") }
      let(:logger) { double("logger", info:nil) }
      let(:package) { Models::Package.make }
      let(:stemcell) { Models::Stemcell.make }
      let(:dependency_key) { 'fake-dependency-key' }
      let(:cache_key) { 'fake-cache-key' }

      subject(:task) { CompileTask.new(package, stemcell, job, dependency_key, cache_key) }

      context 'when global package cache is not used' do
        before { Config.stub(:use_compiled_package_cache?).and_return(false) }
        context 'when compiled package is found in local blobstore' do
          it 'returns it' do
            compiled_package = Models::CompiledPackage.make(package: package, stemcell: stemcell, dependency_key: dependency_key)
            BlobUtil.should_not_receive(:fetch_from_global_cache)
            task.find_compiled_package(logger, event_log).should == compiled_package
          end
        end

        context 'when compiled package is not found in local blobstore' do
          it 'returns nil' do
            BlobUtil.should_not_receive(:fetch_from_global_cache)
            task.find_compiled_package(logger, event_log).should == nil
          end
        end
      end

      context 'when using global package cache' do
        before { Config.stub(:use_compiled_package_cache?).and_return(true) }

        context 'when compiled package is not found in local blobstore' do
          context 'nor was it found in the global one' do
            it 'returns nil' do
              BlobUtil.stub(:exists_in_global_cache?).with(package, task.cache_key).and_return(false)
              task.find_compiled_package(logger, event_log).should == nil
            end
          end

          context 'but it was found in the global blobstore' do
            it 'returns the compiled package' do
              event_log.stub(:track).with(anything).and_yield

              compiled_package = double('compiled package', package: package, stemcell: stemcell, dependency_key: dependency_key)
              BlobUtil.stub(:exists_in_global_cache?).with(package, task.cache_key).and_return(true)
              BlobUtil.should_receive(:fetch_from_global_cache).with(package, stemcell, task.cache_key, task.dependency_key).and_return(compiled_package)
              task.find_compiled_package(logger, event_log).should == compiled_package
            end
          end
        end

        context 'when compiled package is found in local blobstore' do
          it 'returns it' do
            compiled_package = Models::CompiledPackage.make(package: package, stemcell: stemcell, dependency_key: dependency_key)
            BlobUtil.should_not_receive(:fetch_from_global_cache)
            task.find_compiled_package(logger, event_log).should == compiled_package
          end
        end
      end
    end
  end
end
