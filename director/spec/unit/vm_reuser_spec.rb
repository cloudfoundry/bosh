require 'spec_helper'

describe Bosh::Director::VmReuser do
  let(:reuser) { described_class.new }
  let(:reservation) { double(BD::NetworkReservation) }
  let(:network_settings) { {} }
  let(:vm) { BDM::Vm.make }
  let(:stemcell) { BDM::Stemcell.make }

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
