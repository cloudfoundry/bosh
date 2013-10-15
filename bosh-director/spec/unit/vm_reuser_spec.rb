require 'spec_helper'

module Bosh::Director
  describe VmReuser do
    let(:reuser) { described_class.new }
    let(:reservation) { instance_double('Bosh::Director::NetworkReservation') }
    let(:network_settings) { {} }
    let(:vm) { Models::Vm.make }
    let(:stemcell) { Models::Stemcell.make }

    describe '#add_vm' do
      it 'should add a vm to the VmReuser' do
        reuser.get_num_vms(stemcell).should == 0

        reuser.add_vm(reservation, vm, stemcell, network_settings)

        reuser.get_num_vms(stemcell).should == 1
      end
    end

    describe '#remove_vm' do
      it 'should remove a vm from the VmReuser' do
        reuser.add_vm(reservation, vm, stemcell, network_settings)
        reuser.get_num_vms(stemcell).should == 1
        reuser.remove_vm(vm)
        reuser.get_num_vms(stemcell).should == 0
      end
    end
  end
end
