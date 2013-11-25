require 'spec_helper'

module Bosh::Director
  describe VmData do
    let(:vm_data) { described_class.new(reservation, vm, stemcell, network_settings) }
    let(:reservation) { instance_double('Bosh::Director::NetworkReservation') }
    let(:network_settings) { {} }
    let(:vm) { Models::Vm.make }
    let(:stemcell) { Models::Stemcell.make }

    describe '#mark_in_use' do
      context 'in use' do
        it 'should return false if marked for use again' do
          vm_data.mark_in_use.should be(true)
          vm_data.mark_in_use.should be(false)
        end
      end

      context 'not in use' do
        it 'should return true if marked for use' do
          vm_data.mark_in_use.should be(true)
        end
      end
    end

    describe '#release' do
      context 'in use' do
        it 'should set in_use to false' do
          vm_data.mark_in_use
          vm_data.release
          vm_data.in_use?.should be(false)
        end
      end

      context 'not in use' do
        # not defined
      end
    end

    describe '#in_use?' do
      context 'in use' do
        it 'should return true' do
          vm_data.mark_in_use
          vm_data.in_use?.should be(true)
        end
      end

      context 'not in use' do
        it 'should return false' do
          vm_data.in_use?.should be(false)
        end
      end
    end
  end
end
