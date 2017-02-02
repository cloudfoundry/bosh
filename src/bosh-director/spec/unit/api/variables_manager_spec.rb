require 'spec_helper'

describe Bosh::Director::Api::VariablesManager do
  subject(:manager) { described_class.new }

  let (:variable_set_id_1) { 'var_id_1' }
  let (:variable_set_id_2) { 'var_id_2' }
  let (:variable_set_id_3) { 'var_id_3' }
  let (:variable_set_id_4) { 'var_id_4' }
  let (:variable_set_id_5) { 'var_id_5' }

  let(:deployment1) { Bosh::Director::Models::Deployment.make(id: 1, name: 'cookie_deployment', variables_set_id: variable_set_id_1, successful_variables_set_id: variable_set_id_4) }
  let(:deployment2) { Bosh::Director::Models::Deployment.make(id: 2, name: 'chocolate_deployment', variables_set_id: variable_set_id_2, successful_variables_set_id: variable_set_id_3) }
  let(:deployment3) { Bosh::Director::Models::Deployment.make(id: 3, name: 'icecream_deployment', variables_set_id: variable_set_id_5, successful_variables_set_id: variable_set_id_5) }

  describe '#get_variables_for_deployment' do
    context 'when you have multiple deployments' do
      let(:deployment1_variables) { [] }

      before do
        deployment1_variables << Bosh::Director::Models::VariableMapping.make(id: 1, variable_name: 'var1', variable_id: 'id1', set_id: variable_set_id_1, deployment_id: deployment1.id)
        deployment1_variables << Bosh::Director::Models::VariableMapping.make(id: 2, variable_name: 'var2', variable_id: 'id2', set_id: variable_set_id_1, deployment_id: deployment1.id)
        deployment1_variables << Bosh::Director::Models::VariableMapping.make(id: 3, variable_name: 'var3', variable_id: 'id3', set_id: variable_set_id_1, deployment_id: deployment1.id)
        deployment1_variables << Bosh::Director::Models::VariableMapping.make(id: 4, variable_name: 'var3', variable_id: 'id3', set_id: variable_set_id_4, deployment_id: deployment1.id)

        Bosh::Director::Models::VariableMapping.make(id: 5, variable_name: 'var4', variable_id: 'id4', set_id: variable_set_id_2, deployment_id: deployment2.id)
        Bosh::Director::Models::VariableMapping.make(id: 6, variable_name: 'var5', variable_id: 'id5', set_id: variable_set_id_3, deployment_id: deployment2.id)

        Bosh::Director::Models::VariableMapping.make(id: 7, variable_name: 'var6', variable_id: 'id6', set_id: variable_set_id_5, deployment_id: deployment3.id)
      end

      it 'should only return the unique variables associated with that particular deployment' do
        variables = subject.get_variables_for_deployment(deployment1)
        expect(variables).to match_array(deployment1_variables)
      end
    end
  end
end
