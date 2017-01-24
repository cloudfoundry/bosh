require 'spec_helper'

describe Bosh::Director::Api::VariablesManager do
  subject(:manager) { described_class.new }

  let(:variable_set_id) { 'var_id_32' }
  let(:success_variable_set_id) { 'var_success_23' }

  let(:deployment_id) { 1234 }
  let(:deployment_name) { 'COOKIE_CUTTER_DEPLOYMENT' }
  let(:deployment) {
    Bosh::Director::Models::Deployment.make(
      id: deployment_id,
      name: 'COOKIE_CUTTER_DEPLOYMENT',
      variables_set_id: variable_set_id,
      successful_variables_set_id: variable_set_id
    )
  }

  describe '#get_variables_for_deployment' do

    before do
      Bosh::Director::Models::VariableMapping.make(id: 1, variable_name: 'var1', variable_id: 'id1', set_id: variable_set_id)
      Bosh::Director::Models::VariableMapping.make(id: 2, variable_name: 'var2', variable_id: 'id2', set_id: variable_set_id)
      Bosh::Director::Models::VariableMapping.make(id: 3, variable_name: 'var3', variable_id: 'id3', set_id: variable_set_id)
    end

    context 'when variables_set_id and successful_variables_set_id are the same' do
      it 'should return unique variables associated with the id' do
        expected_variables = [
          {
            'id' => 'id1',
            'name' => 'var1'
          },
          {
            'id' => 'id2',
            'name' => 'var2'
          },
          {
            'id' => 'id3',
            'name' => 'var3'
          }
        ]

        variables = subject.get_variables_for_deployment(deployment)
        expect(variables).to eq(expected_variables)
      end
    end

    context 'when variables_set_id and successful_variables_set_id are NOT the same' do

      before do
        Bosh::Director::Models::VariableMapping.make(id: 7, variable_name: 'successVar7', variable_id: 'successId7', set_id: success_variable_set_id)
        deployment[:successful_variables_set_id] = success_variable_set_id
      end

      it 'should return all variables associated with both ids' do

        expected_variables = [
          {
            'id' => 'id1',
            'name' => 'var1'
          },
          {
            'id' => 'id2',
            'name' => 'var2'
          },
          {
            'id' => 'id3',
            'name' => 'var3'
          },
          {
            'id' => 'successId7',
            'name' => 'successVar7'
          }
        ]

        variables = subject.get_variables_for_deployment(deployment)
        expect(variables).to eq(expected_variables)
      end

      it 'should return only the unique variables associated with both ids' do
        Bosh::Director::Models::VariableMapping.make(id: 8, variable_name: 'var1', variable_id: 'id1', set_id: success_variable_set_id)

        expected_variables = [
          {
            'id' => 'id1',
            'name' => 'var1'
          },
          {
            'id' => 'id2',
            'name' => 'var2'
          },
          {
            'id' => 'id3',
            'name' => 'var3'
          },
          {
            'id' => 'successId7',
            'name' => 'successVar7'
          }
        ]

        variables = subject.get_variables_for_deployment(deployment)
        expect(variables).to eq(expected_variables)
        expect(variables.count).to eq(4)
      end
    end
  end
end