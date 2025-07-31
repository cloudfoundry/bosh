require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe CommitInstanceNetworkSettingsStep do
        subject(:step) { described_class.new }
        let(:report) { Stages::Report.new.tap { |report| report.vm = vm } }
        let(:network_plans) do
          [
            NetworkPlanner::Plan.new(reservation: existing_reservation, existing: true),
            NetworkPlanner::Plan.new(reservation: obsolete_reservation, obsolete: true),
            NetworkPlanner::Plan.new(reservation: desired_reservation),
          ]
        end

        let(:existing_ip_address_string) { '1.1.1.1/32' }
        let(:obsolete_ip_address_string) { '2.2.2.2/32' }
        let(:desired_ip_address_string) { '3.3.3.3/32' }

        let(:existing_reservation) { instance_double(NetworkReservation, ip: Bosh::Director::IpAddrOrCidr.new(existing_ip_address_string)) }
        let(:obsolete_reservation) { instance_double(NetworkReservation, ip: Bosh::Director::IpAddrOrCidr.new(obsolete_ip_address_string)) }
        let(:desired_reservation) { instance_double(NetworkReservation, ip: Bosh::Director::IpAddrOrCidr.new(desired_ip_address_string)) }

        let!(:existing_ip_address) { FactoryBot.create(:models_ip_address, address_str: existing_ip_address_string) }
        let!(:obsolete_ip_address) { FactoryBot.create(:models_ip_address, address_str: obsolete_ip_address_string) }
        let!(:desired_ip_address) { FactoryBot.create(:models_ip_address, address_str: desired_ip_address_string) }

        let(:vm) { FactoryBot.create(:models_vm) }

        before { report.network_plans = network_plans }

        describe '#perform' do
          it 'marks the desired plans as existing' do
            step.perform(report)

            expect(report.network_plans.length).to eq(3)

            expect(report.network_plans[0].existing?).to eq(true)
            expect(report.network_plans[1].obsolete?).to eq(true)
            expect(report.network_plans[2].existing?).to eq(true)
          end

          it 'updates IpAddress models with vm_id from vm on report' do
            step.perform(report)

            existing_ip_address.refresh
            obsolete_ip_address.refresh
            desired_ip_address.refresh

            expect(existing_ip_address.vm_id).to eq(vm.id)
            expect(desired_ip_address.vm_id).to eq(vm.id)
            expect(obsolete_ip_address.vm_id).to eq(nil)
          end
        end
      end
    end
  end
end
