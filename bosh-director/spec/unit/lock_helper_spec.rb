# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path('../../spec_helper', __FILE__)

module Bosh::Director
  describe LockHelper do

    class TestClass
      include LockHelper
    end

    before do
      @test_instance = TestClass.new
    end

    describe :with_deployment_lock do
      it 'should support a deployment model or plan' do
        deployment = double(:deployment)
        deployment.stub(:name).and_return('foo')

        lock = double(:lock)
        Lock.stub(:new).with('lock:deployment:foo', { timeout: 10 }).
          and_return(lock)
        lock.should_receive(:lock).and_yield

        called = false
        @test_instance.with_deployment_lock(deployment) do
          called = true
        end
        called.should be(true)
      end

      it 'should support a deployment name' do
        lock = double(:lock)
        Lock.stub(:new).with('lock:deployment:bar', { timeout: 5 }).
          and_return(lock)
        lock.should_receive(:lock).and_yield

        called = false
        @test_instance.with_deployment_lock('bar', timeout: 5) do
          called = true
        end
        called.should be(true)
      end

      it 'should fail for other types' do
        expect { @test_instance.with_deployment_lock(nil, timeout: 5) }.
          to raise_error(ArgumentError)
      end
    end

    describe :with_release_lock do
      it 'should support a release name' do
        lock = double(:lock)
        Lock.stub(:new).with('lock:release:bar', { timeout: 5 }).
          and_return(lock)
        lock.should_receive(:lock).and_yield

        called = false
        @test_instance.with_release_lock('bar', timeout: 5) do
          called = true
        end
        called.should be(true)
      end
    end

    describe :with_release_locks do
      it 'should support a deployment plan' do
        deployment_plan = double(:deployment_plan)
        release_a = double(:release_a)
        release_a.stub(:name).and_return('a')
        release_b = double(:release_b)
        release_b.stub(:name).and_return('b')
        deployment_plan.stub(:releases).and_return([release_a, release_b])

        lock_a = double(:lock_a)
        Lock.stub(:new).with('lock:release:a', { timeout: 5 }).
          and_return(lock_a)

        lock_b = double(:lock_b)
        Lock.stub(:new).with('lock:release:b', { timeout: 5 }).
          and_return(lock_b)

        lock_a.should_receive(:lock).ordered
        lock_b.should_receive(:lock).ordered
        lock_b.should_receive(:release).ordered
        lock_a.should_receive(:release).ordered

        called = false
        @test_instance.with_release_locks(deployment_plan, timeout: 5) do
          called = true
        end
        called.should be(true)
      end
    end

    describe :with_stemcell_lock do
      it 'should support a stemcell name and version' do
        lock = double(:lock)
        Lock.stub(:new).with('lock:stemcells:foo:1.0', { timeout: 5 }).
          and_return(lock)
        lock.should_receive(:lock).and_yield

        called = false
        @test_instance.with_stemcell_lock('foo', '1.0', timeout: 5) do
          called = true
        end
        called.should be(true)
      end
    end

    describe :with_compile_lock do
      it 'should support a package and stemcell id' do
        lock = double(:lock)
        Lock.stub(:new).with('lock:compile:3:4', { timeout: 900 }).
          and_return(lock)
        lock.should_receive(:lock).and_yield

        called = false
        @test_instance.with_compile_lock(3, 4) do
          called = true
        end
        called.should be(true)
      end
    end
  end
end
