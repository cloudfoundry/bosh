require 'spec_helper'

module Bosh::Director
  describe VmData do
    let(:vm_data) { described_class.new(reservation, vm, stemcell, network_settings) }
    let(:reservation) { instance_double('Bosh::Director::NetworkReservation') }
    let(:network_settings) { {} }
    let(:vm) { Models::Vm.make(:agent_id => '123') }
    let(:stemcell) { Models::Stemcell.make }
    let(:reservation) { instance_double('Bosh::Director::NetworkReservation') }

    describe '#agent' do
      it 'creates an agent client for the correct agent' do
        expect(AgentClient).to receive(:with_defaults).with(vm.agent_id)
        vm_data.agent
      end
    end
  end
end
