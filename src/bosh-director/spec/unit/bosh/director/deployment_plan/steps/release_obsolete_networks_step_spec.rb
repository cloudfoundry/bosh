require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe ReleaseObsoleteNetworksStep do
        subject(:step) { described_class.new(ip_provider) }
        let(:report) { Stages::Report.new }
        let(:network_plans) do
          [
            NetworkPlanner::Plan.new(reservation: nil, existing: true),
            NetworkPlanner::Plan.new(reservation: obsolete_reservation, obsolete: true),
            NetworkPlanner::Plan.new(reservation: nil),
          ]
        end
        let(:obsolete_reservation) { double('reservation') }
        let(:ip_provider) { instance_double(IpProvider) }

        before { report.network_plans = network_plans }

        describe '#perform' do
          it 'releases obsolete plans' do
            expect(ip_provider).to receive(:release).with(obsolete_reservation)

            step.perform(report)

            expect(report.network_plans.length).to eq(2)

            expect(report.network_plans[0].existing?).to eq(true)
            expect(report.network_plans[1].desired?).to eq(true)
          end
        end
      end
    end
  end
end
