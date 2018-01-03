require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe CommitInstanceNetworkSettingsStep do
        subject(:step) { described_class.new }
        let(:report) { Stages::Report.new }
        let(:network_plans) do
          [
            NetworkPlanner::Plan.new(reservation: nil, existing: true),
            NetworkPlanner::Plan.new(reservation: nil, obsolete: true),
            NetworkPlanner::Plan.new(reservation: nil),
          ]
        end

        before { report.network_plans = network_plans }

        describe '#perform' do
          it 'marks the desired plans as existing' do
            step.perform(report)
            expect(report.network_plans.length).to eq(3)

            expect(report.network_plans[0].existing?).to eq(true)
            expect(report.network_plans[1].obsolete?).to eq(true)
            expect(report.network_plans[2].existing?).to eq(true)
          end
        end
      end
    end
  end
end
