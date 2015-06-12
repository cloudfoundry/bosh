require 'spec_helper'

module Bosh::Director
  describe VmReuser do
    let(:reuser) { described_class.new }
    let(:reservation) { instance_double('Bosh::Director::NetworkReservation') }
    let(:network_settings) { {} }
    let(:vm) { Models::Vm.make }
    let(:stemcell) { Models::Stemcell.make }
    let(:vm_data) { VmData.new(reservation, vm, stemcell, network_settings) }

    describe '#add_vm' do
      it 'should add a vm to the VmReuser' do
        expect(reuser.get_num_vms(stemcell)).to eq(0)
        reuser.add_vm(vm_data)
        expect(reuser.get_num_vms(stemcell)).to eq(1)
      end
    end

    describe '#get_vm' do
      context 'when there is a vm available for the stemcell' do
        before { reuser.add_vm(vm_data) }

        it 'returns a vm' do
          expect(reuser.get_vm(stemcell)).to eq(vm_data)
        end

        it 'makes the vm unavailable' do
          reuser.get_vm(stemcell)
          expect(reuser.get_vm(stemcell)).to eq(nil)
        end
      end

      context 'when no vm is available for the stemcell' do
        it 'returns nil' do
          expect(reuser.get_vm(stemcell)).to eq(nil)
        end
      end
    end

    describe '#release_vm' do
      context 'when the vm is in use' do
        it 'makes it available again' do
          reuser.add_vm(vm_data)
          reuser.get_vm(stemcell)
          reuser.release_vm(vm_data)
          expect(reuser.get_vm(stemcell)).to eq(vm_data)
        end
      end
    end

    describe '#remove_vm' do
      it 'should remove a vm from the VmReuser' do
        reuser.add_vm(vm_data)
        expect(reuser.get_num_vms(stemcell)).to eq(1)
        reuser.remove_vm(vm_data)
        expect(reuser.get_num_vms(stemcell)).to eq(0)
      end
    end
  end
end
