require 'spec_helper'
require 'bosh/director/models/variable_set'

module Bosh::Director::Models
  describe VariableSet do
    let(:deployment) { Deployment.make(manifest: '') }
    let(:variable_set_1) { described_class.make(id: 1, deployment: deployment) }
    let(:variable_set_2) { described_class.make(id: 999, deployment: deployment) }

    describe '#variables' do
      it 'returns variables associated with variable set' do
        variable_1 = Variable.make(id: 1, variable_id: 'var_id_1', variable_name: 'var_name_1', variable_set: variable_set_1)
        variable_2 = Variable.make(id: 2, variable_id: 'var_id_2', variable_name: 'var_name_2', variable_set: variable_set_1)
        variable_3 = Variable.make(id: 3, variable_id: 'var_id_3', variable_name: 'var_name_3', variable_set: variable_set_1)

        Variable.make(id: 4, variable_id: 'var_id_4', variable_name: 'var_name_4', variable_set: variable_set_2)
        Variable.make(id: 5, variable_id: 'var_id_5', variable_name: 'var_name_5', variable_set: variable_set_2)

        expect(variable_set_1.variables).to match_array([variable_1, variable_2, variable_3])
      end
    end

    describe '#deployment' do
      it 'returns deployment associated with variable set' do
        expect(variable_set_1.deployment).to eq(deployment)
      end
    end

    describe '#instances' do
      it 'returns instances associated with variable set' do
        instance_1 = Instance.make(job: 'job-1', variable_set: variable_set_1)
        instance_2 = Instance.make(job: 'job-2', variable_set: variable_set_1)
        Instance.make(job: 'job-3', variable_set: variable_set_2)

        expect(variable_set_1.instances).to match_array([instance_1, instance_2])
      end
    end

    describe '#before_create' do
      it 'should set created_at' do
        variable_set = FactoryBot.create(:models_variable_set, deployment: deployment)
        expect(variable_set.created_at).to_not be_nil
      end
    end

    describe '#find_variable_by_name' do
      it 'returns associated local variable with given name' do
        var_1 = Variable.make(id: 1, variable_id: 'var_id_1', variable_name: 'var_name_1', variable_set: variable_set_1)
        var_2 = Variable.make(id: 2, variable_id: 'var_id_2', variable_name: 'var_name_2', variable_set: variable_set_1)
        var_3 = Variable.make(id: 44, variable_id: 'var_id_44', variable_name: 'var_name_44', variable_set: variable_set_2)
        var_4 = Variable.make(id: 55, variable_id: 'var_id_55', variable_name: 'var_name_55', variable_set: variable_set_2)
        Variable.make(id: 66, variable_id: 'var_id_66', variable_name: 'i_am_external_provided_variable', variable_set: variable_set_2, is_local: false)

        expect(variable_set_1.find_variable_by_name('var_name_1')).to eq(var_1)
        expect(variable_set_1.find_variable_by_name('var_name_2')).to eq(var_2)
        expect(variable_set_2.find_variable_by_name('var_name_44')).to eq(var_3)
        expect(variable_set_2.find_variable_by_name('var_name_55')).to eq(var_4)

        expect(variable_set_2.find_variable_by_name('i_do_not_exist')).to eq(nil)
        expect(variable_set_2.find_variable_by_name('i_am_external_provided_variable')).to eq(nil)
      end
    end

    describe '#find_provided_variable_by_name' do
      it 'returns associated external variable with given name and provider deployment name' do
        var_1 = Variable.make(id: 1, variable_id: 'var_id_1', variable_name: 'var_name_1', variable_set: variable_set_1, is_local: false, provider_deployment: 'dep-1')
        Variable.make(id: 2, variable_id: 'var_id_2', variable_name: 'var_name_1', variable_set: variable_set_1, is_local: true)

        expect(variable_set_1.find_provided_variable_by_name('var_name_1', 'dep-1')).to eq(var_1)
        expect(variable_set_1.find_provided_variable_by_name('var_name_1', 'i_do_not_exist')).to eq(nil)
      end
    end
  end
end
