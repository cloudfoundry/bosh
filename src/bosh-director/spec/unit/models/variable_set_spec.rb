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
        variable_set = VariableSet.make(deployment: deployment)
        expect(variable_set.created_at).to_not be_nil
      end
    end
  end
end
