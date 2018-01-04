require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Stages
      describe Agenda do
        subject(:agenda) { described_class.new }
        it 'is a struct with fields' do
          expect(agenda).to respond_to(:report)
          expect(agenda).to respond_to(:thread_name)
          expect(agenda).to respond_to(:info)
          expect(agenda).to respond_to(:task_name)
          expect(agenda).to respond_to(:steps)
        end
      end
    end
  end
end
