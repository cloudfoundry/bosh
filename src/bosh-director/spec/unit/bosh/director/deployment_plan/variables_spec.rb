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

    describe '#add' do
      context 'given non empty variables to add' do
        it 'appends to end of non-empty existing spec' do
          variables_spec = [{'name' => 'a', 'type' => 'password'}, {'name' => 'b', 'type' => 'password'}, {'name' => 'c', 'type' => 'password'}]
          variables_object = Variables.new(variables_spec)
          new_variables = Variables.new([{'name' => 'd', 'type' => 'password'}])
          variables_object.add(new_variables)
          expect(variables_object.spec.first).to eq(variables_spec[0])
          expect(variables_object.spec[1]).to eq(variables_spec[1])
          expect(variables_object.spec[2]).to eq(variables_spec[2])
          expect(variables_object.spec[3]).to eq(new_variables.spec.first)
        end

        it 'adds to empty existing spec' do
          variables_object = Variables.new([])
          new_variables = Variables.new([{'name' => 'd', 'type' => 'password'}])
          variables_object.add(new_variables)
          expect(variables_object.spec.first).to eq(new_variables.spec.first)
          expect(variables_object.spec.length).to eq(1)
        end
      end

      context 'given empty variables to add' do
        it 'does not change existing non-empty spec' do
          variables_spec = [{'name' => 'a', 'type' => 'password'}]
          variables_object = Variables.new(variables_spec)
          new_variables = Variables.new([])
          variables_object.add(new_variables)
          expect(variables_object.spec).to eq(variables_spec)
        end

        it 'does not change existing empty spec' do
          variables_object = Variables.new([])
          new_variables = Variables.new([])
          variables_object.add(new_variables)
          expect(variables_object.spec.length).to eq(0)
        end
      end
    end
  end
end