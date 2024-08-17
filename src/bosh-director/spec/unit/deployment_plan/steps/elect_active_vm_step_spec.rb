require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe ElectActiveVmStep do
        subject(:step) { described_class.new }

        let(:instance) { FactoryBot.create(:models_instance) }
        let!(:vm) { Models::Vm.make(instance: instance, active: false, cpi: 'vm-cpi') }
        let(:report) { Stages::Report.new.tap { |r| r.vm = vm } }

        it 'marks the new vm as active' do
          step.perform(report)
          expect(vm.reload.active).to eq true
        end

        context 'when there is already an active vm' do
          let!(:active_vm) { Models::Vm.make(instance: instance, active: true, cpi: 'vm-cpi') }
          it 'marks the old vm as inactive' do
            step.perform(report)
            expect(active_vm.reload.active).to eq false
            expect(vm.reload.active).to eq true
          end
        end
      end
    end
  end
end
