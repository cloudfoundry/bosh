require 'spec_helper'
require 'bosh/director/models/variable'

module Bosh::Director::Models
  describe Variable do
    let(:deployment) { Deployment.make(manifest: '') }
    let(:variable_set_1) { FactoryBot.create(:models_variable_set, id: 1, deployment: deployment) }
    let(:variable_set_2) { FactoryBot.create(:models_variable_set, id: 999, deployment: deployment) }

    describe '#variable_set' do
      it 'return variable_set' do
        variable_set = FactoryBot.create(:models_variable_set, id: 2, deployment: deployment)
        variable = Variable.make(id: 1, variable_id: 'var_id_1', variable_name: 'var_name_1', variable_set_id: variable_set.id)
        expect(variable.variable_set).to eq(variable_set)
      end
    end

    describe '#validate' do
      it 'validates presence of variable_id' do
        expect {
          Variable.make(id: 1, variable_name: 'var_name_1', variable_set: variable_set_1)
        }.to raise_error(Sequel::ValidationFailed, 'variable_id presence')
      end

      it 'validates presence of variable_name' do
        expect {
          Variable.make(id: 1, variable_id: 'var_id_1', variable_set: variable_set_1)
        }.to raise_error(Sequel::ValidationFailed, 'variable_name presence')
      end
    end
  end
end
