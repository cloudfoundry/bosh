require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe Variables do

    describe '#initialize' do
      it 'defaults to empty array if spec is nil' do
        variables = Variables.new(nil)
        expect(variables.spec.count).to eq(0)
      end
    end

    describe '#get_variable' do
      context 'when variable with the same name exists' do
        let(:variables_spec) do
          [{'name' =>'smurf', 'type' => 'password'}]
        end

        it 'returns the a copy of the variable' do
          smurf_variable = Variables.new(variables_spec).get_variable('smurf')

          expect(smurf_variable).to eq({'name' =>'smurf', 'type' => 'password'})
          expect(smurf_variable).to_not equal(variables_spec[0])
        end
      end

      context 'when variable with the same name does NOT exist' do
        let(:variables_spec) do
          [{'name' =>'no-smurf', 'type' => 'password'}]
        end

        it 'returns the a copy of the variable' do
          smurf_variable = Variables.new(variables_spec).get_variable('smurf')
          expect(smurf_variable).to be_nil

          smurf_variable = Variables.new([]).get_variable('smurf')
          expect(smurf_variable).to be_nil

          smurf_variable = Variables.new(nil).get_variable('smurf')
          expect(smurf_variable).to be_nil
        end
      end
    end

    describe '#contains_variable?' do
      it 'should return false if variable does not exist' do
        variables_spec = [{'name' =>'a', 'type' => 'password'}]
        expect(Variables.new(variables_spec).contains_variable?('b')).to be_falsey
      end

      it 'should return true if variable exists' do
        variables_spec = [{'name' => 'a', 'type' =>'password'}, {'name' => 'b', 'type' =>'password'}, {'name' => 'c', 'type' =>'password'}]
        expect(Variables.new(variables_spec).contains_variable?('a')).to be_truthy
      end
    end

    describe '#spec' do
      it 'returns a copy of the variables spec' do
        variables_spec = [{'name' => 'a', 'type' =>'password'}, {'name' => 'b', 'type' =>'password'}, {'name' => 'c', 'type' =>'password'}]

        variables_object = Variables.new(variables_spec)

        expect(variables_object.spec).to eq(variables_spec)
        expect(variables_object.spec).to_not equal(variables_spec)
      end
    end
  end
end