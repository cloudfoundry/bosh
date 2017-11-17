require 'spec_helper'
require 'bosh/director/models/instance'

module Bosh::Director::Models
  describe Instance do
    subject { described_class.make(job: 'test-job') }

    describe '#cloud_properties_hash' do
      context 'when the cloud_properties are not nil' do
        it 'should return the parsed json' do
          subject.cloud_properties = '{"foo":"bar"}'
          expect(subject.cloud_properties_hash).to eq({'foo' => 'bar'})
        end
      end

      context "when the instance's cloud_properties are nil" do
        context 'when the model is missing data' do
          it 'does not error' do
            expect(subject.cloud_properties_hash).to eq({})
          end
        end

        context 'when the vm_type has cloud_properties' do
          it 'should return cloud_properties from vm_type' do
            subject.spec = {'vm_type' => {'cloud_properties' => {'foo' => 'bar'}}}
            expect(subject.cloud_properties_hash).to eq({'foo' => 'bar'})
          end
        end

        context 'when the vm_type has no cloud properties' do
          it 'does not error' do
            subject.spec = {'vm_type' => {'cloud_properties' => nil}}
            expect(subject.cloud_properties_hash).to eq({})
          end
        end
      end
    end

    describe '#latest_rendered_templates_archive' do
      def perform
        subject.latest_rendered_templates_archive
      end

      context 'when instance model has no associated rendered templates archives' do
        it 'returns nil' do
          expect(perform).to be_nil
        end
      end

      context 'when instance model has multiple associated rendered templates archives' do
        let!(:latest) do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-latest-blob-id',
            instance: subject,
            created_at: Time.new(2013, 02, 01),
          )
        end

        let!(:not_latest) do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-stale-blob-id',
            instance: subject,
            created_at: Time.new(2013, 01, 01),
          )
        end

        it 'returns most recent archive for associated instance' do
          expect(perform).to eq(latest)
        end

        it 'does not account for archives for other instances' do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-non-associated-latest-blob-id',
            instance: described_class.make,
            created_at: latest.created_at + 10_000,
          )

          expect(perform).to eq(latest)
        end
      end
    end

    describe '#stale_rendered_templates_archives' do
      def perform
        subject.stale_rendered_templates_archives
      end

      context 'when instance model has no associated rendered templates archives' do
        it 'returns empty dataset' do
          expect(perform.to_a).to eq([])
        end
      end

      context 'when instance model has multiple associated rendered templates archives' do
        let!(:latest) do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-latest-blob-id',
            instance: subject,
            created_at: Time.new(2013, 02, 01),
          )
        end

        let!(:not_latest) do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-stale-blob-id',
            instance: subject,
            created_at: Time.new(2013, 01, 01),
          )
        end

        it 'returns non-latest archives for associated instance' do
          expect(perform.to_a).to eq([not_latest])
        end

        it 'does not include archives for other instances' do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-non-associated-latest-blob-id',
            instance: described_class.make,
            created_at: not_latest.created_at - 10_000,
          )

          expect(perform.to_a).to eq([not_latest])
        end
      end
    end

    describe '#name' do
      it 'returns the instance name' do
        expect(subject.name).to eq("test-job/#{subject.uuid}")
      end
    end

    context 'apply' do
      before do
        subject.spec=({
          'resource_pool' =>
            {'name' => 'a',
              'cloud_properties' => {},
              'stemcell' => {
                'name' => 'ubuntu-stemcell',
                'version' => '1'
              }
            }
        })
      end

      it 'should have vm_type' do
        expect(subject.spec_p('vm_type')).to eq({'name' => 'a', 'cloud_properties' => {}})
      end

      it 'should have stemcell' do
        expect(subject.spec_p('stemcell')).to eq({
          'alias' => 'a',
          'name' => 'ubuntu-stemcell',
          'version' => '1'
        })
      end
    end

    context 'spec_p' do
      it 'should return the property at the given dot separated path' do
        subject.spec=({'foo' => {'bar' => 'baz'}})
        expect(subject.spec_p('foo.bar')).to eq('baz')
      end

      context 'when the spec is nil' do
        it 'returns nil' do
          subject.spec_json = nil
          expect(subject.spec_json).to eq(nil)
          expect(subject.spec_p('foo')).to eq(nil)
          expect(subject.spec_p('foo.bar')).to eq(nil)
        end
      end

      context 'when the path does not exist' do
        it 'returns nil' do
          subject.spec=({'foo' => 'bar'})
          expect(subject.spec_p('nothing')).to eq(nil)
        end
      end

      context 'when none of the path exists' do
        it 'returns nil' do
          subject.spec=({'foo' => 'bar'})
          expect(subject.spec_p('nothing.anywhere')).to eq(nil)
        end
      end

      context 'when the path refers to a value that is not a hash' do
        it 'returns nil' do
          subject.spec=({'foo' => 'bar'})
          expect(subject.spec_p('foo.bar')).to eq(nil)
        end
      end
    end

    context 'spec' do
      context 'when spec_json persisted in database has no resource pool' do
        it 'returns spec_json as is' do
          subject.spec=({
            'vm_type' => 'stuff',
            'stemcell' => 'stuff'
          })

          expect(subject.spec['vm_type']).to eq('stuff')
          expect(subject.spec['stemcell']).to eq('stuff')
        end
      end

      context 'when spec_json has resource pool persisted in database' do
        context 'when resource_pool has vm_type and stemcell information' do
          it 'returns vm_type and stemcell values' do
            subject.spec=({
              'resource_pool' =>
                {'name' => 'a',
                  'cloud_properties' => {},
                  'stemcell' => {
                    'name' => 'ubuntu-stemcell',
                    'version' => '1'
                  }
                }
            })

            expect(subject.spec['vm_type']).to eq(
              {'name' => 'a',
                'cloud_properties' => {}
              }
            )

            expect(subject.spec['stemcell']).to eq(
              {'name' => 'ubuntu-stemcell',
                'version' => '1',
                'alias' => 'a'
              }
            )
          end
        end

        context 'when resource_pool DOES NOT have vm_type and stemcell information' do
          it 'returns vm_type only' do
            subject.spec=({
              'resource_pool' =>
                {'name' => 'a',
                  'cloud_properties' => {},
                }
            })
            expect(subject.spec['vm_type']).to eq(
              {'name' => 'a',
                'cloud_properties' => {}
              }
            )
          end
        end
      end
    end

    context 'vm_env' do
      it 'returns env contents' do
        subject.spec=({'env' => {'a' => 'a_value'}})
        expect(subject.vm_env).to eq({'a' => 'a_value'})
      end

      it 'returns empty hash when env is nil' do
        subject.spec=({'env' => nil})
        expect(subject.vm_env).to eq({})
      end

      it 'returns empty hash when spec is nil' do
        subject.spec=(nil)
        expect(subject.vm_env).to eq({})
      end
    end

    describe '#lifecycle' do

      context "when spec has 'lifecycle'" do
        context "and it is 'service'" do
          before(:each) { subject.spec=({'lifecycle' => 'service'}) }

          it "returns 'service'" do
            expect(subject.lifecycle).to eq('service')
          end
        end

        context "and it is 'errand'" do
          before(:each) { subject.spec=({'lifecycle' => 'errand'}) }

          it "returns 'errand'" do
            expect(subject.lifecycle).to eq('errand')
          end
        end
      end

      context "when spec has 'lifecycle=nil'" do
        before(:each) do
          subject.spec=({'lifecycle' => nil})
        end

        it 'returns nil without falling back to parsing the manifest' do
          expect(subject.lifecycle).to be_nil
        end
      end

      context 'when model has no spec' do
        before(:each) { subject.spec=(nil) }
        it 'returns nil' do
          expect(subject.spec).to be_nil
          expect(subject.lifecycle).to be_nil
        end
      end
    end

    describe '#expects_vm?' do

      context "when lifecycle is 'errand'" do
        before(:each) { allow(subject).to receive(:lifecycle).and_return('errand') }

        it "doesn't expect vm" do
          expect(subject.expects_vm?).to eq(false)
        end
      end

      context "when lifecycle is 'service'" do
        before(:each) { allow(subject).to receive(:lifecycle).and_return('service') }

        ['started', 'stopped'].each do |state|

          context "when state is '#{state}'" do
            before(:each) { allow(subject).to receive(:state).and_return(state) }

            it 'expects a vm' do
              expect(subject.expects_vm?).to eq(true)
            end
          end
        end

        context "when state is 'detached'" do
          before(:each) { allow(subject).to receive(:state).and_return('detached') }

          it "doesn't expect vm" do
            expect(subject.expects_vm?).to eq(false)
          end
        end
      end
    end

    it 'has a one-to-many relationship to vms' do
      vm1 = BD::Models::Vm.make(instance_id: subject.id)
      vm2 = BD::Models::Vm.make(instance_id: subject.id)

      expect(subject.vms).to contain_exactly(vm1, vm2)

      new_instance = BD::Models::Instance.make

      new_instance.add_vm vm1
      subject.refresh
      expect(subject.vms).to contain_exactly(vm2)
      expect(new_instance.vms).to contain_exactly(vm1)
    end

    describe '#active_vm' do
      let!(:vm1) { BD::Models::Vm.make(instance_id: subject.id) }
      let!(:vm2) { BD::Models::Vm.make(instance_id: subject.id, active: true) }

      it 'returns vm of #vms that is marked active' do
        expect(subject.active_vm).to eq(vm2)
      end
    end

    describe '#active_vm=' do
      let!(:vm1) { BD::Models::Vm.make(instance_id: subject.id) }
      let!(:vm2) { BD::Models::Vm.make(instance_id: subject.id, active: true) }

      it 'changes what vm is returned for #active_vm' do
        expect(subject.active_vm).to eq(vm2)

        subject.active_vm = vm1

        expect(subject.active_vm).to eq(vm1)
      end

      context 'when updating new vm to be active fails' do
        before { allow(vm1).to receive(:update).and_raise }

        it 'is transactional' do
          expect(subject.active_vm).to eq(vm2)

          expect { subject.active_vm = vm1 }.to raise_error

          expect(subject.active_vm).to eq(vm2)
        end
      end

      context 'when updating with a nil vm' do
        it 'the instance should not have any active_vms' do
          subject.active_vm = nil

          expect(subject.active_vm).to eq(nil)
        end
      end

      context 'when instance does not already have an active vm' do
        before { vm2.update(active: false) }

        it 'sets the given vm to be active' do
          expect(subject.active_vm).to eq(nil)

          subject.active_vm = vm2

          expect(subject.active_vm).to eq(vm2)
        end
      end
    end

    context 'with active vm' do
      before do
        vm = BD::Models::Vm.make(agent_id: 'my-agent-id', cid: 'my-cid', trusted_certs_sha1: 'trusted-sha', instance_id: subject.id)
        subject.active_vm = vm
        subject.save
      end

      describe 'agent_id' do
        it 'references agent_id from active vm' do
          expect(subject.agent_id).to eq('my-agent-id')
        end
      end

      describe 'vm_cid' do
        it 'returns active vms cid' do
          expect(subject.vm_cid).to eq('my-cid')
        end
      end

      describe 'vm_created_at' do
        it 'references created_at from active vm' do
          expect(subject.vm_created_at).to eq(subject.active_vm.created_at.utc.iso8601)
        end
      end

      describe 'trusted_certs_sha1' do
        it 'returns active vms trusted_certs_sha1' do
          expect(subject.trusted_certs_sha1).to eq('trusted-sha')
        end
      end
    end

    context 'without active vm' do
      describe 'agent_id' do
        it 'is nil' do
          expect(subject.agent_id).to be_nil
        end
      end

      describe 'vm_cid' do
        it 'is nil' do
          expect(subject.vm_cid).to be_nil
        end
      end

      describe 'vm_created_at' do
        it 'is nil' do
          expect(subject.vm_created_at).to be_nil
        end
      end

      describe 'trusted_certs_sha1' do
        it 'returns sha1 digest of empty string' do
          expect(subject.trusted_certs_sha1).to eq(::Digest::SHA1.hexdigest(''))
        end
      end
    end

    describe '#has_important_vm?' do
      let!(:vm) { BD::Models::Vm.make(instance_id: instance_with_important_vm.id, active: true) }
      let!(:ignored_vm) { BD::Models::Vm.make(instance_id: ignored_instance.id, active: true) }
      let!(:stopped_vm) { BD::Models::Vm.make(instance_id: stopped_instance.id, active: true) }
      let(:instance_with_important_vm) { BD::Models::Instance.make(state: 'started', ignore: false) }
      let(:ignored_instance) { BD::Models::Instance.make(state: 'started', ignore: true) }
      let(:stopped_instance) { BD::Models::Instance.make(state: 'stopped', ignore: false) }
      let(:instance_with_no_active_vm) { BD::Models::Instance.make(state: 'started', ignore: false) }

      it 'only returns true when model has active vm and is not stopped and is not ignored' do
        expect(instance_with_important_vm.has_important_vm?).to eq(true)
        expect(ignored_instance.has_important_vm?).to eq(false)
        expect(stopped_instance.has_important_vm?).to eq(false)
        expect(instance_with_no_active_vm.has_important_vm?).to eq(false)
      end
    end

    describe '#most_recent_inactive_vm' do
      let!(:vm) { BD::Models::Vm.make(instance_id: instance.id, active: true) }
      let(:instance) {BD::Models::Instance.make(state: 'started', ignore: false)}

      context 'has one active and two inactive vms' do
        let!(:old_inactive_vm) { BD::Models::Vm.make(instance_id: instance.id, active: false) }
        let!(:new_inactive_vm) { BD::Models::Vm.make(instance_id: instance.id, active: false) }

        it 'returns the most recent inactive vm' do
          expect(instance.most_recent_inactive_vm).to eq(new_inactive_vm)
        end
      end

      context 'has only active vm' do
        it 'returns the most recent inactive vm' do
          expect(instance.most_recent_inactive_vm).to eq(nil)
        end
      end
    end
  end
end
