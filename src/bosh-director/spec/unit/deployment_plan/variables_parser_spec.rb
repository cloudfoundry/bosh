require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::VariablesSpecParser do

    subject(:variables_parser) { described_class.new(logger) }

    describe '#parse' do
      context 'when variables_spec passed is nil' do
        it 'should handle it without error' do
          variables = variables_parser.parse(nil)
          expect(variables.spec.count).to eq(0)
        end
      end

      context 'when variables_spec passed is NOT nil' do
        context 'when variables_spec is NOT an array' do
          it 'should return an error' do
            expect {
              variables_parser.parse({'smurf' => 'snoopy'})
            }.to raise_error(VariablesInvalidFormat, /Key 'variables' expects an array, but received 'Hash'/)
          end
        end

        context 'when variables_spec is an array' do
          context 'when variables_spec is empty' do
            it 'should handle it without error' do
              variables = variables_parser.parse([])
              expect(variables.spec.count).to eq(0)
            end
          end

          context 'when variables_spec is NOT empty' do
            context 'when all variables items are NOT hashes' do
              it 'should return an error' do
                variables_spec = [{'name' => 'vroom', 'type' => 'password'}, 'i should not be here']
                expect {
                  variables_parser.parse(variables_spec)
                }.to raise_error(VariablesInvalidFormat, /All 'variables' elements should be Hashes/)
              end
            end

            context 'when all variables items are hashes' do
              context "when an item in the array does NOT specify 'name' or 'type'" do
                context 'name' do
                  it 'should return an error when name key is missing' do
                    variables_spec = [{'type' => '2'}, {'name' => 'Bob', 'type' => 'password'}]
                    expect {
                      variables_parser.parse(variables_spec)
                    }.to raise_error(VariablesInvalidFormat, /At least one of the variables is missing the 'name' key; 'name' must be specified/)
                  end

                  it 'should return an error when name value is empty or nil' do
                    variables_spec = [{'name' => nil, 'type' => 'dd'}, {'name' => 'Bob', 'type' => 'password'}]
                    expect {
                      variables_parser.parse(variables_spec)
                    }.to raise_error(VariablesInvalidFormat, /At least one of the variables has an empty 'name'; 'name' must not be empty or nil/)

                    variables_spec = [{'name' => ' ', 'type' => 'dd'}, {'name' => 'Bob', 'type' => 'password'}]
                    expect {
                      variables_parser.parse(variables_spec)
                    }.to raise_error(VariablesInvalidFormat, /At least one of the variables has an empty 'name'; 'name' must not be empty or nil/)
                  end
                end

                context 'type' do
                  it 'should return an error when type key is missing' do
                    variables_spec = [{'name' => 'smurf'}, {'name' => 'Bob', 'type' => 'password'}]
                    expect {
                      variables_parser.parse(variables_spec)
                    }.to raise_error(VariablesInvalidFormat, /Type for variable 'smurf' is missing; 'type' must be specified/)
                  end

                  it 'should return an error when type value is empty or nil' do
                    variables_spec = [{'name' => 'smurf', 'type' => nil}, {'name' => 'Bob', 'type' => 'password'}]
                    expect {
                      variables_parser.parse(variables_spec)
                    }.to raise_error(VariablesInvalidFormat, /Type for variable 'smurf' is nil; 'type' must not be nil/)

                    variables_spec = [{'name' => 'smurf', 'type' => ' '}, {'name' => 'Bob', 'type' => 'password'}]
                    expect {
                      variables_parser.parse(variables_spec)
                    }.to raise_error(VariablesInvalidFormat, /Type for variable 'smurf' is empty; 'type' must not be empty/)
                  end
                end
              end

              context 'when all items in array have a name and type' do
                context 'when there are duplicate names' do
                  it 'raises an error' do
                    variables_spec = [
                      {'name' => 'smurf', 'type' => 'certificate'},
                      {'name' => 'smurf', 'type' => 'password'},
                      {'name' => 'cat', 'type' => 'password'}
                    ]
                    expect {
                      variables_parser.parse(variables_spec)
                    }.to raise_error(VariablesInvalidFormat, /Some of the variables have duplicate names, eg: 'smurf'/)
                  end
                end

                context 'when there are no duplicate names' do
                  it 'parses it correctly' do
                    variables_spec = [
                      {'name' => 'smurf', 'type' => 'certificate'},
                      {'name' => 'gargamel', 'type' => 'password'},
                      {'name' => 'cat', 'type' => 'luck'},
                      {'name' => 'kitten', 'type' => 'gold'}
                    ]

                    variables_obj = variables_parser.parse(variables_spec)

                    expect(variables_obj.spec.count).to eq(4)
                    expect(variables_obj.get_variable('cat')).to eq({'name' => 'cat', 'type' => 'luck'})
                    expect(variables_obj.get_variable('gargamel')).to eq({'name' => 'gargamel', 'type' => 'password'})
                    expect(variables_obj.get_variable('kitten')).to eq({'name' => 'kitten', 'type' => 'gold'})
                  end

                  context 'when the type is NOT a string' do
                    it 'throws an error' do
                      variables_spec = [
                        {'name' => 'smurf', 'type' => 42},
                        {'name' => 'gargamel', 'type' => 'password'},
                      ]

                      expect {
                        variables_parser.parse(variables_spec)
                      }.to raise_error(VariablesInvalidFormat, /Type for variable 'smurf' must be a String, but was '42'/)
                    end
                  end

                  context 'when a variable specifies options' do
                    context 'when the option is not a hash' do
                      it 'should return an error' do
                        variables_spec = [
                          {'name' => 'smurf', 'type' => 'certificate', 'options' => 'meow'},
                          {'name' => 'rat', 'type' => 'password', 'options' => {}},
                          {'name' => 'cat', 'type' => 'password', 'options' => {'cat' => 'happy'}}
                        ]
                        expect {
                          variables_parser.parse(variables_spec)
                        }.to raise_error(VariablesInvalidFormat, /options of variable with name 'smurf' is not a Hash/)
                      end
                    end

                    context 'when the option is a hash' do
                      it 'parses it correctly' do
                        variables_spec = [
                          {'name' => 'smurf', 'type' => 'certificate', 'options' => {'sound' => 'vroom'}},
                          {'name' => 'gargamel', 'type' => 'password', 'options' => nil},
                          {'name' => 'cat', 'type' => 'luck', 'options' => {}},
                          {'name' => 'kitten', 'type' => 'gold'}
                        ]

                        variables_obj = variables_parser.parse(variables_spec)

                        expect(variables_obj.spec.count).to eq(4)
                        expect(variables_obj.get_variable('smurf')).to eq({'name' => 'smurf', 'type' => 'certificate', 'options' => {'sound' => 'vroom'}})
                        expect(variables_obj.get_variable('gargamel')).to eq({'name' => 'gargamel', 'type' => 'password', 'options' => nil})
                        expect(variables_obj.get_variable('cat')).to eq( {'name' => 'cat', 'type' => 'luck', 'options' => {}})
                        expect(variables_obj.get_variable('kitten')).to eq({'name' => 'kitten', 'type' => 'gold'})
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end