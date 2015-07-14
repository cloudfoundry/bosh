require 'spec_helper'

module Bosh::Director
  describe InstanceReuser do
    let(:reuser) { described_class.new }
    let(:reservation) { instance_double('Bosh::Director::NetworkReservation') }
    let(:network_settings) { {} }
    let(:vm) { Models::Vm.make }
    let(:stemcell) { Models::Stemcell.make }
    let(:vm_data) { VmData.new(reservation, vm, stemcell, network_settings) }

    let(:second_stemcell) { Models::Stemcell.make }
    let(:second_vm) { Models::Vm.make }
    let(:second_vm_data) { VmData.new(reservation, second_vm, second_stemcell, network_settings) }

    describe '#add_in_use_instance' do
      it 'should add a vm to the InstanceReuser' do
        expect(reuser.get_num_instances(stemcell)).to eq(0)
        reuser.add_in_use_instance(vm_data, stemcell)
        expect(reuser.get_num_instances(stemcell)).to eq(1)
      end
      it 'should not offer an added in use vm until it is released' do
        expect(reuser.get_instance(stemcell)).to be_nil
        reuser.add_in_use_instance(vm_data, stemcell)
        expect(reuser.get_instance(stemcell)).to be_nil
        reuser.release_instance(vm_data)
        expect(reuser.get_instance(stemcell)).to eq(vm_data)
        expect(reuser.get_instance(stemcell)).to be_nil
      end
    end

    describe '#get_instance' do
      it 'should make the vm unavailable' do
        reuser.add_in_use_instance(vm_data, stemcell)
        reuser.release_instance(vm_data)
        reuser.get_instance(stemcell)
        expect(reuser.get_instance(stemcell)).to be_nil

      end
    end

    describe '#get_num_instances' do
      it 'should return the total count of in use vms and idle vms from the given stemcell' do
        expect(reuser.get_num_instances(stemcell)).to eq(0)

        reuser.add_in_use_instance(vm_data, stemcell)
        expect(reuser.get_num_instances(stemcell)).to eq(1)
        reuser.release_instance(vm_data)
        expect(reuser.get_num_instances(stemcell)).to eq(1)

        reuser.add_in_use_instance(second_vm_data, second_stemcell)
        expect(reuser.get_num_instances(stemcell)).to eq(1)
        expect(reuser.get_num_instances(second_stemcell)).to eq(1)
      end
    end

    describe '#each' do
      it 'should iterate in use vms and idle vms' do
        reuser.add_in_use_instance(vm_data, stemcell)
        reuser.release_instance(vm_data)
        reuser.add_in_use_instance(second_vm_data, second_stemcell)

        iterated = []
        reuser.each do |vm_data|
          iterated << vm_data
        end

        expect(iterated).to match_array([vm_data, second_vm_data])
      end
    end

    describe '#release_instance' do
      context 'when the vm is in use' do
        it 'makes it available again' do
          reuser.add_in_use_instance(vm_data, stemcell)
          reuser.get_instance(stemcell)
          reuser.release_instance(vm_data)
          expect(reuser.get_instance(stemcell)).to eq(vm_data)
        end
      end
    end

    describe '#remove_instance' do
      it 'should remove a vm from the InstanceReuser' do
        reuser.add_in_use_instance(vm_data, stemcell)
        expect(reuser.get_num_instances(stemcell)).to eq(1)
        reuser.remove_instance(vm_data)
        expect(reuser.get_num_instances(stemcell)).to eq(0)
      end
    end
  end
end
