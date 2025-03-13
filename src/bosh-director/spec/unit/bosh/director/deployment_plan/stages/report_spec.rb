require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Stages
      describe Report do
        subject(:report) { described_class.new }
        it 'is a struct with fields' do
          expect(report).to respond_to(:vm)
          expect(report).to respond_to(:network_plans)
          expect(report).to respond_to(:disk_hint)
        end
      end
    end
  end
end
