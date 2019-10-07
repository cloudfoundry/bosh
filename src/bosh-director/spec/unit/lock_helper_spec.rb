require File.expand_path('../spec_helper', __dir__)

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
        allow(deployment).to receive(:name).and_return('foo')

        lock = double(:lock)
        allow(Lock).to receive(:new).with('lock:deployment:foo', timeout: 10, deployment_name: 'foo')
                                    .and_return(lock)
        expect(lock).to receive(:lock).and_yield

        called = false
        @test_instance.with_deployment_lock(deployment) do
          called = true
        end
        expect(called).to be(true)
      end

      it 'should support a deployment name' do
        lock = double(:lock)
        allow(Lock).to receive(:new).with('lock:deployment:bar', timeout: 5, deployment_name: 'bar')
                                    .and_return(lock)
        expect(lock).to receive(:lock).and_yield

        called = false
        @test_instance.with_deployment_lock('bar', timeout: 5) do
          called = true
        end
        expect(called).to be(true)
      end

      it 'should fail for other types' do
        expect { @test_instance.with_deployment_lock(nil, timeout: 5) }
          .to raise_error(ArgumentError)
      end
    end

    describe :locked_deployments do
      let(:expired) { Time.now - 1000000 }
      let(:not_expired) { Time.now + 1000000 }

      context 'with some deployments locked' do
        it 'returns non-expired deployment locks' do
          Models::Lock.create(name: 'lock:deployment:example1', uid: 'who-cares1', expired_at: expired)
          locked = Models::Lock.create(name: 'lock:deployment:example2', uid: 'who-cares2', expired_at: not_expired)
          expect(@test_instance.locked_deployments).to eq([locked])
        end
      end
    end

    describe :deployment_locked? do
      let(:expired_at) { Time.now + 1000000 }

      context 'with a deployment model or plan' do
        let(:name) { 'example' }
        let(:deployment) { double(:deployment, name: name) }

        context 'and the deployment is currently locked' do
          before do
            Models::Lock.create(name: "lock:deployment:#{name}", uid: 'who-cares', expired_at: expired_at)
          end

          it 'returns true' do
            expect(@test_instance.deployment_locked?(deployment)).to eq(true)
          end

          context 'when the lock is expired' do
            let(:expired_at) { Time.now - 1000 }

            it 'returns false' do
              expect(@test_instance.deployment_locked?(deployment)).to eq(false)
            end
          end
        end

        context 'and the deployment is currently unlocked' do
          it 'returns false' do
            expect(@test_instance.deployment_locked?(deployment)).to eq(false)
          end
        end
      end

      context 'with a deployment name' do
        let(:name) { 'example' }

        context 'and the deployment is currently locked' do
          before do
            Models::Lock.create(name: "lock:deployment:#{name}", uid: 'who-cares', expired_at: expired_at)
          end

          it 'returns true' do
            expect(@test_instance.deployment_locked?(name)).to eq(true)
          end

          context 'when the lock is expired' do
            let(:expired_at) { Time.now - 1000 }

            it 'returns false' do
              expect(@test_instance.deployment_locked?(name)).to eq(false)
            end
          end
        end

        context 'and the deployment is currently unlocked' do
          it 'returns false' do
            expect(@test_instance.deployment_locked?(name)).to eq(false)
          end
        end
      end

      it 'should fail for other types' do
        expect { @test_instance.deployment_locked?(nil) }.to raise_error(ArgumentError)
      end
    end

    describe :with_release_lock do
      it 'creates a lock for the given name' do
        lock = double(:lock)
        allow(Lock).to receive(:new).with('lock:release:bar', timeout: 5).and_return(lock)
        expect(lock).to receive(:lock).ordered
        expect(lock).to receive(:release).ordered

        called = false
        @test_instance.with_release_lock('bar', timeout: 5) do
          called = true
        end
        expect(called).to be(true)
      end
    end

    describe :with_release_locks do
      it 'creates locks for each release name in a consistent order' do
        lock_a = double(:lock_a)
        allow(Lock).to receive(:new).with('lock:release:a', timeout: 5).and_return(lock_a)

        lock_b = double(:lock_b)
        allow(Lock).to receive(:new).with('lock:release:b', timeout: 5).and_return(lock_b)

        expect(lock_a).to receive(:lock).ordered
        expect(lock_b).to receive(:lock).ordered
        expect(lock_b).to receive(:release).ordered
        expect(lock_a).to receive(:release).ordered

        called = false
        @test_instance.with_release_locks(%w[b a], timeout: 5) do
          called = true
        end
        expect(called).to be(true)
      end
    end

    describe :with_stemcell_lock do
      it 'should support a stemcell name and version' do
        lock = double(:lock)
        allow(Lock).to receive(:new).with('lock:stemcells:foo:1.0', timeout: 5)
                                    .and_return(lock)
        expect(lock).to receive(:lock).and_yield

        called = false
        @test_instance.with_stemcell_lock('foo', '1.0', timeout: 5) do
          called = true
        end
        expect(called).to be(true)
      end
    end

    describe :with_compile_lock do
      it 'should support a package and stemcell id' do
        lock = double(:lock)
        allow(Lock).to receive(:new).with('lock:compile:3:4', timeout: 900, deployment_name: 'foo')
                                    .and_return(lock)
        expect(lock).to receive(:lock).and_yield

        called = false
        @test_instance.with_compile_lock(3, 4, 'foo') do
          called = true
        end
        expect(called).to be(true)
      end
    end

    describe :with_network_lock do
      it 'should supports a network name' do
        lock = double(:lock)
        allow(Lock).to receive(:new)
          .with('lock:networks:network1', timeout: 20)
          .and_return(lock)

        expect(lock).to receive(:lock).and_yield

        called = false
        @test_instance.with_network_lock('network1', timeout: 20) do
          called = true
        end
        expect(called).to be(true)
      end
    end
  end
end
