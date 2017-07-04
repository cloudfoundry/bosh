require 'spec_helper'

module Bosh::Director::ConfigServer
  describe EnabledClient do
    subject(:client) { EnabledClient.new(http_client, director_name, logger) }
    let(:director_name) { 'smurf_director_name' }
    let(:deployment_name) { 'deployment_name' }
    let(:deployment_attrs) { { id: 1, name: deployment_name } }
    let(:logger) { double('Logging::Logger') }
    let(:variables_set_id) { 2000 }
    let(:success_post_response) {
      generate_success_response({ :id => 'some_id1'}.to_json)
    }
    let(:http_client) { double('Bosh::Director::ConfigServer::HTTPClient') }

    let(:event_manager) {Bosh::Director::Api::EventManager.new(true)}
    let(:task_id) {42}
    let(:update_job) {instance_double(Bosh::Director::Jobs::UpdateDeployment, username: 'user', task_id: task_id, event_manager: event_manager)}

    let(:success_response) do
      result = SampleSuccessResponse.new
      result.body = '{}'
      result
    end

    def prepend_namespace(name)
      "/#{director_name}/#{deployment_name}/#{name}"
    end

    before do
      deployment_model = Bosh::Director::Models::Deployment.make(deployment_attrs)
      Bosh::Director::Models::VariableSet.make(id: variables_set_id, deployment: deployment_model, writable: true)

      allow(logger).to receive(:info)
      allow(Bosh::Director::Config).to receive(:current_job).and_return(update_job)
    end

    describe '#interpolate' do
      let(:deployment_name) { 'my_deployment_name' }
      let(:deployment_model) { instance_double(Bosh::Director::Models::Deployment) }
      let(:raw_hash) do
        {
          'properties' => {
            'integer_allowed' => '((/integer_placeholder))',
            'nil_allowed' => '((/nil_placeholder))',
            'empty_allowed' => '((/empty_placeholder))'
          },
          'i_am_a_hash' => {
            'i_am_an_array' => [
              {
                'name' => 'test_job',
                'properties' => {'job_prop' => '((/string_placeholder))'}
              }
            ]
          },
          'i_am_another_array' => [
            {'env' => {'env_prop' => '((/hash_placeholder))'}}
          ],
          'my_value_will_be_a_hash' => '((/hash_placeholder))'
        }
      end
      let(:interpolated_hash) do
        {
          'properties' => {
            'integer_allowed' => 123,
            'nil_allowed' => nil,
            'empty_allowed' => ''
          },
          'i_am_a_hash' => {
            'i_am_an_array' => [
              {
                'name' => 'test_job',
                'properties' => {'job_prop' => 'i am a string'}
              }
            ]
          },
          'i_am_another_array' => [
            {'env' => {'env_prop' => hash_placeholder_value}}
          ],
          'my_value_will_be_a_hash' => hash_placeholder_value
        }
      end
      let(:hash_placeholder_value) do
        {
          'ca' => {
            'level_1' => 'level_1_value',
            'level_2' => {
              'level_2_1' => 'level_2_1_value'
            }
          },
          'private_key' => 'abc123'
        }
      end

      before do
        allow(deployment_model).to receive(:name).and_return(deployment_name)
      end

      context 'when object to be interpolated is NOT nil' do
        context 'when object to be interpolated is a hash' do
          context 'when all placeholders syntax is correct' do
            let(:integer_placeholder) { {'data' => [{'name' => "#{prepend_namespace('integer_placeholder')}", 'value' => 123, 'id' => '1'}]} }
            let(:nil_placeholder) { {'data' => [{'name' => "#{prepend_namespace('nil_placeholder')}", 'value' => nil, 'id' => '2'}]} }
            let(:empty_placeholder) { {'data' => [{'name' => "#{prepend_namespace('empty_placeholder')}", 'value' => '', 'id' => '3'}]} }
            let(:string_placeholder) { {'data' => [{'name' => "#{prepend_namespace('string_placeholder')}", 'value' => 'i am a string', 'id' => '4'}]} }
            let(:hash_placeholder) do
              {
                'data' => [
                  {
                    'name' => "#{prepend_namespace('hash_placeholder')}",
                    'value' => hash_placeholder_value,
                    'id' => '5'
                  }
                ]
              }
            end

            let(:mock_config_store) do
              {
                '/integer_placeholder' => generate_success_response(integer_placeholder.to_json),
                '/nil_placeholder' => generate_success_response(nil_placeholder.to_json),
                '/empty_placeholder' => generate_success_response(empty_placeholder.to_json),
                '/string_placeholder' => generate_success_response(string_placeholder.to_json),
                '/hash_placeholder' => generate_success_response(hash_placeholder.to_json),
              }
            end

            let(:variable_name) { '/boo' }
            let(:variable_id) { 'cfg-svr-id' }
            let(:variable_value) { 'var_val' }

            let(:response_body_id) { {'name' => variable_name, 'value' => variable_value, 'id' => variable_id} }
            let(:response_body_name) { {'data' => [response_body_id]} }
            let(:mock_response) { generate_success_response(response_body_name.to_json) }

            before do
              mock_config_store.each do |name, value|
                result_body = JSON.parse(value.body)
                allow(http_client).to receive(:get).with(name).and_return(generate_success_response(result_body.to_json))
              end
              allow(http_client).to receive(:get).with('/boo').and_return(mock_response)
            end

            it 'should use the latest variables from the config server' do
              result = client.interpolate({'key' => "((#{variable_name}))"})
              expect(result['key']).to eq('var_val')
            end

            context 'when variable does not use an absolute name' do
              let(:variable_name) { 'boo' }

              it 'should error' do
                expect {
                  client.interpolate({'key' => "((#{variable_name}))"})
                }.to raise_error Bosh::Director::ConfigServerIncorrectNameSyntax
              end
            end

            context 'when a variable has sub-keys' do
              let(:variable_value) { {'cert' => 'my cert', 'key' => 'my key', 'ca' => 'my ca'} }

              it 'should get the sub-value as needed' do
                result = client.interpolate({'key' => '((/boo.ca))'})
                expect(result['key']).to eq('my ca')
              end
            end

            context 'when response received from server is not in the expected format' do
              let(:manifest_hash) do
                {
                  'name' => 'deployment_name',
                  'properties' => {
                    'name' => '((/bad))'
                  }
                }
              end

              [
                {'response' => 'Invalid JSON response',
                 'message' => '- Failed to fetch variable \'/bad\' from config server: Invalid JSON response'},

                {'response' => {'x' => {}},
                 'message' => '- Failed to fetch variable \'/bad\' from config server: Expected data to be an array'},

                {'response' => {'data' => {'value' => 'x'}},
                 'message' => '- Failed to fetch variable \'/bad\' from config server: Expected data to be an array'},

                {'response' => {'data' => []},
                 'message' => '- Failed to fetch variable \'/bad\' from config server: Expected data to be non empty array'},

                {'response' => {'data' => [{'name' => 'name1', 'id' => 'id1', 'val' => 'x'}]},
                 'message' => '- Failed to fetch variable \'/bad\' from config server: Expected data[0] to have key \'value\''},

                {'response' => {'data' => [{'name' => 'name1', 'value' => 'x'}]},
                 'message' => '- Failed to fetch variable \'/bad\' from config server: Expected data[0] to have key \'id\''},

              ].each do |entry|
                it 'raises an error' do
                  allow(http_client).to receive(:get).with('/bad').and_return(generate_success_response(entry['response'].to_json))
                  expect {
                    client.interpolate(manifest_hash)
                  }.to raise_error { |error|
                    expect(error).to be_a(Bosh::Director::ConfigServerFetchError)
                    expect(error.message).to include(entry['message'])
                  }
                end
              end
            end

            context 'when name is not found in the config_server' do
              let(:manifest_hash) do
                {
                  'name' => 'deployment_name',
                  'properties' => {
                    'name' => '((/missing_placeholder))'
                  }
                }
              end

              it 'should raise a missing name error message' do
                allow(http_client).to receive(:get).with('/missing_placeholder').and_return(SampleNotFoundResponse.new)

                expect {
                  client.interpolate(manifest_hash)
                }.to raise_error { |error|
                  expect(error).to be_a(Bosh::Director::ConfigServerFetchError)
                  expect(error.message).to include("- Failed to find variable '/missing_placeholder' from config server: HTTP code '404'")
                }
              end
            end

            context 'when some placeholders have the dot syntax' do
              before do
                raw_hash['my_value_will_be_a_hash'] = '((/hash_placeholder.private_key))'
                interpolated_hash['my_value_will_be_a_hash'] = 'abc123'
              end

              it 'extracts the variable name from placeholder name' do
                expect(client.interpolate(raw_hash)).to eq(interpolated_hash)
              end

              context 'when placeholders have multiple dot levels' do
                before do
                  raw_hash['my_value_will_be_a_hash'] = '((/hash_placeholder.ca.level_2.level_2_1))'
                  interpolated_hash['my_value_will_be_a_hash'] = 'level_2_1_value'
                end

                it 'extracts value from placeholder name' do
                  expect(client.interpolate(raw_hash)).to eq(interpolated_hash)
                end
              end

              context 'when all parts of dot syntax are not found' do
                before do
                  raw_hash['my_value_will_be_a_hash'] = '((/hash_placeholder.ca.level_n.level_n_1))'
                end

                it 'fails to find values and throws formatting error' do
                  expect {
                    client.interpolate(raw_hash)
                  }.to raise_error("- Failed to fetch variable '/hash_placeholder' " +
                                     "from config server: Expected parent '/hash_placeholder.ca' hash to have key 'level_n'")
                end
              end

              context 'when multiple errors occur because parts of dot syntax is not found' do
                before do
                  raw_hash['my_value_will_be_a_hash'] = '((/hash_placeholder.ca.level_n.level_n_1))'
                  raw_hash['my_value_will_be_an_other_hash'] = '((/hash_placeholder.ca.level_m.level_m_1))'
                end

                it 'fails to find all values and throws formatting error' do
                  expect {
                    client.interpolate(raw_hash)
                  }.to raise_error { |error|
                    expect(error).to be_a(Bosh::Director::ConfigServerFetchError)
                    expect(error.message).to include("- Failed to fetch variable '/hash_placeholder' from config server: Expected parent '/hash_placeholder.ca' hash to have key 'level_n'")
                    expect(error.message).to include("- Failed to fetch variable '/hash_placeholder' from config server: Expected parent '/hash_placeholder.ca' hash to have key 'level_m'")
                  }
                end
              end

              context 'when placeholders use bad dot syntax' do
                before do
                  raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.ca...level_1))'
                end

                it 'fails to find value and throws formatting error' do
                  expect {
                    client.interpolate(raw_hash)
                  }.to raise_error { |error|
                    expect(error).to be_a(Bosh::Director::ConfigServerIncorrectNameSyntax)
                    expect(error.message).to include("Variable name 'hash_placeholder.ca...level_1' syntax error: Must not contain consecutive dots")
                  }
                end
              end

              it 'returns an error for non absolute path placeholders' do
                raw_hash['properties']['some-new-relative-key'] = '((some-relative-var))'
                expect {
                  client.interpolate(raw_hash)
                }.to raise_error { |error|
                  expect(error.message).to eq("Relative paths are not allowed in this context. The following must be be switched to use absolute paths: 'some-relative-var'")
                }
              end
            end
          end

          context 'when some placeholders have invalid name syntax' do
            let(:provided_hash) do
              {
                'properties' => {
                  'integer_allowed' => '((int&&&&eger_placeholder))',
                  'nil_allowed' => '((nil_place holder))',
                  'empty_allowed' => '((emp**ty_placeholder))'
                },
                'i_am_a_hash' => {
                  'i_am_an_array' => [
                    {
                      'name' => 'test_job',
                      'properties' => {'job_prop' => '((job_placeholder+++ ))'}
                    }
                  ]
                }
              }
            end

            # TODO: make sure all the errors are displayed
            it 'should raise an error' do
              expect {
                client.interpolate(provided_hash)
              }.to raise_error Bosh::Director::ConfigServerIncorrectNameSyntax,
                               "Variable name 'int&&&&eger_placeholder' must only contain alphanumeric, underscores, dashes, or forward slash characters"
            end
          end
        end
        context 'when object to be interpolated is NOT a hash' do
          it 'raises an error' do
            expect {
              client.interpolate('i am not a hash')
            }.to raise_error "Unable to interpolate provided object. Expected a 'Hash', got 'String'"
          end
        end
      end

      context 'when object to be interpolated in is nil' do
          it 'should return nil' do
            expect(client.interpolate(nil)).to be_nil
          end
        end
    end

    describe '#interpolate_with_versioning' do
      let(:deployment_name) { 'my_deployment_name' }
      let(:deployment_model) { instance_double(Bosh::Director::Models::Deployment) }
      let(:variable_set_model) { instance_double(Bosh::Director::Models::VariableSet) }
      let(:raw_hash) do
        {
          'properties' => {
            'integer_allowed' => '((integer_placeholder))',
            'nil_allowed' => '((nil_placeholder))',
            'empty_allowed' => '((empty_placeholder))'
          },
          'i_am_a_hash' => {
            'i_am_an_array' => [
              {
                'name' => 'test_job',
                'properties' => {'job_prop' => '((string_placeholder))'}
              }
            ]
          },
          'i_am_another_array' => [
            {'env' => {'env_prop' => '((hash_placeholder))'}}
          ],
          'my_value_will_be_a_hash' => '((hash_placeholder))'
        }
      end
      let(:interpolated_hash) do
        {
          'properties' => {
            'integer_allowed' => 123,
            'nil_allowed' => nil,
            'empty_allowed' => ''
          },
          'i_am_a_hash' => {
            'i_am_an_array' => [
              {
                'name' => 'test_job',
                'properties' => {'job_prop' => 'i am a string'}
              }
            ]
          },
          'i_am_another_array' => [
            {'env' => {'env_prop' => hash_placeholder_value}}
          ],
          'my_value_will_be_a_hash' => hash_placeholder_value
        }
      end
      let(:hash_placeholder_value) do
        {
          'ca' => {
            'level_1' => 'level_1_value',
            'level_2' => {
              'level_2_1' => 'level_2_1_value'
            }
          },
          'private_key' => 'abc123'
        }
      end

      shared_examples :variable_name_dot_syntax do
        context 'when some placeholders have the dot syntax' do
          before do
            raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.private_key))'
            interpolated_hash['my_value_will_be_a_hash'] = 'abc123'
          end

          it 'extracts the variable name from placeholder name' do
            expect(client.interpolate_with_versioning(raw_hash, variable_set_model)).to eq(interpolated_hash)
          end

          context 'when placeholders have multiple dot levels' do
            before do
              raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.ca.level_2.level_2_1))'
              interpolated_hash['my_value_will_be_a_hash'] = 'level_2_1_value'
            end

            it 'extracts value from placeholder name' do
              expect(client.interpolate_with_versioning(raw_hash, variable_set_model)).to eq(interpolated_hash)
            end
          end

          context 'when all parts of dot syntax are not found' do
            before do
              raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.ca.level_n.level_n_1))'
            end

            it 'fails to find values and throws formatting error' do
              expect {
                client.interpolate_with_versioning(raw_hash, variable_set_model)
              }.to raise_error("- Failed to fetch variable '/smurf_director_name/my_deployment_name/hash_placeholder' " +
                                 "from config server: Expected parent '/smurf_director_name/my_deployment_name/hash_placeholder.ca' hash to have key 'level_n'")
            end
          end

          context 'when multiple errors occur because parts of dot syntax is not found' do
            before do
              raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.ca.level_n.level_n_1))'
              raw_hash['my_value_will_be_an_other_hash'] = '((hash_placeholder.ca.level_m.level_m_1))'
            end

            it 'fails to find all values and throws formatting error' do
              expect {
                client.interpolate_with_versioning(raw_hash, variable_set_model)
              }.to raise_error { |error|
                expect(error).to be_a(Bosh::Director::ConfigServerFetchError)
                expect(error.message).to include("- Failed to fetch variable '/smurf_director_name/my_deployment_name/hash_placeholder' from config server: Expected parent '/smurf_director_name/my_deployment_name/hash_placeholder.ca' hash to have key 'level_n'")
                expect(error.message).to include("- Failed to fetch variable '/smurf_director_name/my_deployment_name/hash_placeholder' from config server: Expected parent '/smurf_director_name/my_deployment_name/hash_placeholder.ca' hash to have key 'level_m'")
              }
            end
          end

          context 'when placeholders use bad dot syntax' do
            before do
              raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.ca...level_1))'
            end

            it 'fails to find value and throws formatting error' do
              expect {
                client.interpolate_with_versioning(raw_hash, variable_set_model)
              }.to raise_error { |error|
                expect(error).to be_a(Bosh::Director::ConfigServerIncorrectNameSyntax)
                expect(error.message).to include("Variable name 'hash_placeholder.ca...level_1' syntax error: Must not contain consecutive dots")
              }
            end
          end

          context 'when absolute path is required' do
            it 'returns an error for non absolute path placeholders' do
              expect {
                client.interpolate_with_versioning(raw_hash, variable_set_model, {must_be_absolute_name: true})
              }.to raise_error { |error|
                expect(error.message).to eq("Relative paths are not allowed in this context. The following must be be switched to use absolute paths: 'integer_placeholder', 'nil_placeholder', 'empty_placeholder', 'string_placeholder', 'hash_placeholder', 'hash_placeholder.private_key'")
              }
            end
          end
        end
      end

      before do
        allow(deployment_model).to receive(:name).and_return(deployment_name)
        allow(variable_set_model).to receive(:deployment).and_return(deployment_model)
      end

      context 'when object to be interpolated is NOT nil' do
        context 'when object to be interpolated is a hash' do
          context 'when all placeholders syntax is correct' do


            let(:integer_placeholder) { {'data' => [{'name' => "#{prepend_namespace('integer_placeholder')}", 'value' => 123, 'id' => '1'}]} }
            let(:nil_placeholder) { {'data' => [{'name' => "#{prepend_namespace('nil_placeholder')}", 'value' => nil, 'id' => '2'}]} }
            let(:empty_placeholder) { {'data' => [{'name' => "#{prepend_namespace('empty_placeholder')}", 'value' => '', 'id' => '3'}]} }
            let(:string_placeholder) { {'data' => [{'name' => "#{prepend_namespace('string_placeholder')}", 'value' => 'i am a string', 'id' => '4'}]} }
            let(:hash_placeholder) do
              {
                'data' => [
                  {
                    'name' => "#{prepend_namespace('hash_placeholder')}",
                    'value' => hash_placeholder_value,
                    'id' => '5'
                  }
                ]
              }
            end

            let(:mock_config_store) do
              {
                prepend_namespace('integer_placeholder') => generate_success_response(integer_placeholder.to_json),
                prepend_namespace('nil_placeholder') => generate_success_response(nil_placeholder.to_json),
                prepend_namespace('empty_placeholder') => generate_success_response(empty_placeholder.to_json),
                prepend_namespace('string_placeholder') => generate_success_response(string_placeholder.to_json),
                prepend_namespace('hash_placeholder') => generate_success_response(hash_placeholder.to_json),
              }
            end

            context 'when there is no variable set' do
              let(:variable_name) { '/boo' }
              let(:variable_id) { 'cfg-svr-id' }
              let(:variable_value) { 'var_val' }

              let(:response_body_id) { {'name' => variable_name, 'value' => variable_value, 'id' => variable_id} }
              let(:response_body_name) { {'data' => [response_body_id]} }
              let(:mock_response) { generate_success_response(response_body_name.to_json) }

              before do
                allow(http_client).to receive(:get).with('/boo').and_return(mock_response)
              end

              it 'should raise an error' do
                expect {
                  client.interpolate_with_versioning({'key' => "((#{variable_name}))"}, nil)
                }.to raise_error "Variable Set cannot be nil."
              end
            end

            context 'when all the variables to be fetched were already fetched within the provided variable set context' do
              before do
                mock_config_store.each do |name, value|
                  result_data = JSON.parse(value.body)['data'][0]
                  variable_id = result_data['id']

                  variable_model = instance_double(Bosh::Director::Models::Variable)
                  allow(variable_model).to receive(:variable_name).and_return(name)
                  allow(variable_model).to receive(:variable_id).and_return(variable_id)
                  allow(variable_set_model).to receive(:find_variable_by_name).with(name).and_return(variable_model)

                  allow(http_client).to receive(:get_by_id).with(variable_id).and_return(generate_success_response(result_data.to_json))
                end
              end

              it 'should request all variables by id and returns the interpolated hash' do
                mock_config_store.each do |_, value|
                  result_data = JSON.parse(value.body)['data'][0]
                  variable_id = result_data['id']

                  expect(http_client).to receive(:get_by_id).with(variable_id).and_return(generate_success_response(result_data.to_json))
                end

                expect(client.interpolate_with_versioning(raw_hash, variable_set_model)).to eq(interpolated_hash)
              end

              it 'should return a new copy of the original manifest' do
                expect(client.interpolate_with_versioning(raw_hash, variable_set_model)).to eq(interpolated_hash)
              end

              context 'when an id is not found in the config server' do
                before do
                  mock_config_store.each do |_, value|
                    result_data = JSON.parse(value.body)['data'][0]
                    variable_id = result_data['id']
                    allow(http_client).to receive(:get_by_id).with(variable_id).and_return(SampleNotFoundResponse.new)
                  end
                end

                it 'returns all the errors correctly formatted' do
                  expected_error_msg = <<-EXPECTED.strip
- Failed to find variable '/smurf_director_name/my_deployment_name/integer_placeholder' with id '1' from config server: HTTP code '404'
- Failed to find variable '/smurf_director_name/my_deployment_name/nil_placeholder' with id '2' from config server: HTTP code '404'
- Failed to find variable '/smurf_director_name/my_deployment_name/empty_placeholder' with id '3' from config server: HTTP code '404'
- Failed to find variable '/smurf_director_name/my_deployment_name/string_placeholder' with id '4' from config server: HTTP code '404'
- Failed to find variable '/smurf_director_name/my_deployment_name/hash_placeholder' with id '5' from config server: HTTP code '404'
                  EXPECTED

                  expect {
                    client.interpolate_with_versioning(raw_hash, variable_set_model)
                  }.to raise_error { |e|
                    expect(e.message).to eq(expected_error_msg)
                  }
                end
              end

              context 'when config server throws an error while fetching values' do
                before do
                  mock_config_store.each do |_, value|
                    result_data = JSON.parse(value.body)['data'][0]
                    variable_id = result_data['id']
                    allow(http_client).to receive(:get_by_id).with(variable_id).and_return(SampleForbiddenResponse.new)
                  end
                end

                it 'returns all the errors correctly formatted' do
                  expected_error_msg = <<-EXPECTED.strip
- Failed to fetch variable '/smurf_director_name/my_deployment_name/integer_placeholder' with id '1' from config server: HTTP code '403'
- Failed to fetch variable '/smurf_director_name/my_deployment_name/nil_placeholder' with id '2' from config server: HTTP code '403'
- Failed to fetch variable '/smurf_director_name/my_deployment_name/empty_placeholder' with id '3' from config server: HTTP code '403'
- Failed to fetch variable '/smurf_director_name/my_deployment_name/string_placeholder' with id '4' from config server: HTTP code '403'
- Failed to fetch variable '/smurf_director_name/my_deployment_name/hash_placeholder' with id '5' from config server: HTTP code '403'
                  EXPECTED

                  expect {
                    client.interpolate_with_versioning(raw_hash, variable_set_model)
                  }.to raise_error { |e|
                    expect(e.message).to eq(expected_error_msg)
                  }
                end
              end

              context 'when options passed contain ignored subtrees' do
                let(:ignored_subtrees) do
                  index_integer = Integer

                  ignored_subtrees = []
                  ignored_subtrees << ['properties', 'integer_allowed']
                  ignored_subtrees << ['i_am_a_hash', 'i_am_an_array', index_integer, 'properties']
                  ignored_subtrees
                end

                let(:interpolated_hash) do
                  {
                    'properties' => {
                      'integer_allowed' => '((integer_placeholder))',
                      'nil_allowed' => nil,
                      'empty_allowed' => ''
                    },
                    'i_am_a_hash' => {
                      'i_am_an_array' => [
                        {
                          'name' => 'test_job',
                          'properties' => {'job_prop' => '((string_placeholder))'}
                        }
                      ]
                    },
                    'i_am_another_array' => [
                      {'env' => {'env_prop' => hash_placeholder_value}}
                    ],
                    'my_value_will_be_a_hash' => hash_placeholder_value
                  }
                end

                it 'does NOT replace values in ignored subtrees' do
                  expect(http_client).to_not receive(:get_by_id).with('1')
                  expect(http_client).to_not receive(:get_by_id).with('4')
                  expect(client.interpolate_with_versioning(raw_hash, variable_set_model, {subtrees_to_ignore: ignored_subtrees})).to eq(interpolated_hash)
                end
              end

              context 'when some placeholders begin with a !' do
                before do
                  raw_hash['properties'] = {
                    '!integer_allowed' => '((integer_placeholder))',
                    '!nil_allowed' => '((nil_placeholder))',
                    '!empty_allowed' => '((empty_placeholder))'
                  }

                  interpolated_hash['properties'] =  {
                    '!integer_allowed' => 123,
                    '!nil_allowed' => nil,
                    '!empty_allowed' => ''
                  }
                end

                it 'should strip the exclamation mark' do
                  mock_config_store.each do |_, value|
                    result_data = JSON.parse(value.body)['data'][0]
                    variable_id = result_data['id']

                    expect(http_client).to receive(:get_by_id).with(variable_id).and_return(generate_success_response(result_data.to_json))
                  end

                  expect(client.interpolate_with_versioning(raw_hash, variable_set_model)).to eq(interpolated_hash)
                end
              end

              context 'when some placeholders have the dot syntax' do
                before do
                  raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.private_key))'
                  interpolated_hash['my_value_will_be_a_hash'] = 'abc123'
                end

                it 'extracts the variable name from placeholder name' do
                  expect(client.interpolate_with_versioning(raw_hash, variable_set_model)).to eq(interpolated_hash)
                end

                context 'when placeholders have multiple dot levels' do
                  before do
                    raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.ca.level_2.level_2_1))'
                    interpolated_hash['my_value_will_be_a_hash'] = 'level_2_1_value'
                  end

                  it 'extracts value from placeholder name' do
                    expect(client.interpolate_with_versioning(raw_hash, variable_set_model)).to eq(interpolated_hash)
                  end
                end

                context 'when all parts of dot syntax are not found' do
                  before do
                    raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.ca.level_n.level_n_1))'
                  end

                  it 'fails to find values and throws formatting error' do
                    expect {
                      client.interpolate_with_versioning(raw_hash, variable_set_model)
                    }.to raise_error("- Failed to fetch variable '/smurf_director_name/my_deployment_name/hash_placeholder' " +
                                       "from config server: Expected parent '/smurf_director_name/my_deployment_name/hash_placeholder.ca' hash to have key 'level_n'")
                  end
                end

                context 'when multiple errors occur because parts of dot syntax is not found' do
                  before do
                    raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.ca.level_n.level_n_1))'
                    raw_hash['my_value_will_be_an_other_hash'] = '((hash_placeholder.ca.level_m.level_m_1))'
                  end

                  it 'fails to find all values and throws formatting error' do
                    expect {
                      client.interpolate_with_versioning(raw_hash, variable_set_model)
                    }.to raise_error { |error|
                      expect(error).to be_a(Bosh::Director::ConfigServerFetchError)
                      expect(error.message).to include("- Failed to fetch variable '/smurf_director_name/my_deployment_name/hash_placeholder' from config server: Expected parent '/smurf_director_name/my_deployment_name/hash_placeholder.ca' hash to have key 'level_n'")
                      expect(error.message).to include("- Failed to fetch variable '/smurf_director_name/my_deployment_name/hash_placeholder' from config server: Expected parent '/smurf_director_name/my_deployment_name/hash_placeholder.ca' hash to have key 'level_m'")
                    }
                  end
                end

                context 'when placeholders use bad dot syntax' do
                  before do
                    raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.ca...level_1))'
                  end

                  it 'fails to find value and throws formatting error' do
                    expect {
                      client.interpolate_with_versioning(raw_hash, variable_set_model)
                    }.to raise_error { |error|
                      expect(error).to be_a(Bosh::Director::ConfigServerIncorrectNameSyntax)
                      expect(error.message).to include("Variable name 'hash_placeholder.ca...level_1' syntax error: Must not contain consecutive dots")
                    }
                  end
                end

                context 'when absolute path is required' do
                  it 'returns an error for non absolute path placeholders' do
                    expect {
                      client.interpolate_with_versioning(raw_hash, variable_set_model, {must_be_absolute_name: true})
                    }.to raise_error { |error|
                      expect(error.message).to eq("Relative paths are not allowed in this context. The following must be be switched to use absolute paths: 'integer_placeholder', 'nil_placeholder', 'empty_placeholder', 'string_placeholder', 'hash_placeholder', 'hash_placeholder.private_key'")
                    }
                  end
                end
              end

              context 'when response received from server is not in the expected format' do
                let(:raw_hash) do
                  {
                    'name' => 'deployment_name',
                    'properties' => {
                      'name' => '((/bad))'
                    }
                  }
                end

                [
                  {'response' => 'Invalid JSON response',
                   'message' => "- Failed to fetch variable '/bad' with id '20' from config server: Invalid JSON response"},

                  {'response' => {'id' => 'some-id'},
                   'message' => "- Failed to fetch variable '/bad' from config server: Expected response to have key 'value'"},

                  {'response' => {'value' => 'some-value-foo'},
                   'message' => "- Failed to fetch variable '/bad' from config server: Expected response to have key 'id'"},

                  {'response' => {},
                   'message' => "- Failed to fetch variable '/bad' from config server: Expected response to have key 'id'"},

                  {'response' => [{'name' => 'name1', 'id' => 'id1', 'val' => 'x'}, {'name' => 'name2', 'id' => 'id2', 'val' => 'y'}],
                   'message' => "- Failed to fetch variable '/bad' from config server: Expected response to be a hash, got 'Array'"},
                ].each do |entry|
                  it 'raises an error' do
                    variable_model = instance_double(Bosh::Director::Models::Variable)
                    allow(variable_model).to receive(:variable_name).and_return('/bad')
                    allow(variable_model).to receive(:variable_id).and_return('20')
                    allow(variable_set_model).to receive(:find_variable_by_name).with('/bad').and_return(variable_model)
                    allow(http_client).to receive(:get_by_id).with('20').and_return(generate_success_response(entry['response'].to_json))

                    expect {
                      client.interpolate_with_versioning(raw_hash, variable_set_model)
                    }.to raise_error { |error|
                      expect(error).to be_a(Bosh::Director::ConfigServerFetchError)
                      expect(error.message).to include(entry['message'])
                    }
                  end
                end
              end

              it_behaves_like :variable_name_dot_syntax
            end

            context 'when all the variables to be fetched are not in the current set' do
              before do
                mock_config_store.each do |name, value|
                  allow(variable_set_model).to receive(:find_variable_by_name).with(name).and_return(nil)
                end
              end

              context 'when variable set is writable' do
                before do
                  allow(variable_set_model).to receive(:writable).and_return(true)

                  mock_config_store.each do |name, value|
                    result_body = JSON.parse(value.body)
                    variable_id = result_body['data'][0]['id']

                    allow(http_client).to receive(:get).with(name).and_return(generate_success_response(result_body.to_json))
                    allow(variable_set_model).to receive(:add_variable).with({:variable_name => name, :variable_id => variable_id})
                  end
                end

                it 'should add the name to id mapping for the current set to database' do
                  expect(client.interpolate_with_versioning(raw_hash, variable_set_model)).to eq(interpolated_hash)
                end

                context 'when the variable was added to the current set by another thread' do
                  before do
                    mock_config_store.each do |name, value|
                      result_body = JSON.parse(value.body)
                      result_data = result_body['data'][0]
                      variable_id = result_data['id']

                      variable_model = instance_double(Bosh::Director::Models::Variable)
                      allow(variable_model).to receive(:variable_name).and_return(name)
                      allow(variable_model).to receive(:variable_id).and_return(variable_id)

                      allow(variable_set_model).to receive(:find_variable_by_name).with(name).and_return(nil, variable_model)

                      allow(variable_set_model).to receive(:add_variable)
                                                     .with({:variable_name => name, :variable_id => variable_id})
                                                     .and_raise(Sequel::UniqueConstraintViolation.new)

                      allow(http_client).to receive(:get_by_id)
                                              .with(variable_id)
                                              .and_return(generate_success_response(result_data.to_json))
                    end
                  end
                  it 'should fetch by id from database' do
                    expect(client.interpolate_with_versioning(raw_hash, variable_set_model)).to eq(interpolated_hash)
                  end
                end

                it_behaves_like :variable_name_dot_syntax
              end

              context 'when variable set is NOT writable' do
                before do
                  allow(variable_set_model).to receive(:writable).and_return(false)
                end
                it 'should raise an error' do
                  expect {
                    client.interpolate_with_versioning(raw_hash, variable_set_model)
                  }.to raise_error { |error|
                    expect(error).to be_a(Bosh::Director::ConfigServerInconsistentVariableState)
                    expect(error.message).to include("Expected variable '/smurf_director_name/my_deployment_name/integer_placeholder' to be already versioned in deployment 'my_deployment_name'")
                  }
                end
              end
            end

          end

          context 'when some placeholders have invalid name syntax' do
            let(:provided_hash) do
              {
                'properties' => {
                  'integer_allowed' => '((int&&&&eger_placeholder))',
                  'nil_allowed' => '((nil_place holder))',
                  'empty_allowed' => '((emp**ty_placeholder))'
                },
                'i_am_a_hash' => {
                  'i_am_an_array' => [
                    {
                      'name' => 'test_job',
                      'properties' => {'job_prop' => '((job_placeholder+++ ))'}
                    }
                  ]
                }
              }
            end

            # TODO: make sure all the errors are displayed
            it 'should raise an error' do
              expect {
                client.interpolate_with_versioning(provided_hash, variable_set_model)
              }.to raise_error Bosh::Director::ConfigServerIncorrectNameSyntax,
                               "Variable name 'int&&&&eger_placeholder' must only contain alphanumeric, underscores, dashes, or forward slash characters"
            end
          end
        end

        context 'when object to be interpolated is NOT a hash' do
          it 'raises an error' do
            expect {
              client.interpolate_with_versioning('i am not a hash', variable_set_model)
            }.to raise_error "Unable to interpolate provided object. Expected a 'Hash', got 'String'"
          end
        end
      end

      context 'when object to be interpolated in is nil' do
        it 'should return nil' do
          expect(client.interpolate_with_versioning(nil, variable_set_model)).to be_nil
        end
      end
    end

    describe '#interpolate_cross_deployment_link' do
      def prepend_provider_namespace(name)
        "/#{director_name}/#{provider_deployment_name}/#{name}"
      end

      let(:integer_placeholder) { {'data' => [{'name' => "#{prepend_provider_namespace('integer_placeholder')}", 'value' => 123, 'id' => '1'}]} }
      let(:cert_placeholder) { {'data' => [{'name' => "#{prepend_provider_namespace('cert_placeholder')}", 'value' => {'ca' => 'ca_value', 'private_key' => 'abc123'}, 'id' => '2'}]} }
      let(:nil_placeholder) { {'data' => [{'name' => "#{prepend_provider_namespace('nil_placeholder')}", 'value' => nil, 'id' => '3'}]} }
      let(:empty_placeholder) { {'data' => [{'name' => "#{prepend_provider_namespace('empty_placeholder')}", 'value' => '', 'id' => '4'}]} }
      let(:string_placeholder) { {'data' => [{'name' => "#{prepend_provider_namespace('instance_placeholder')}", 'value' => 'test1', 'id' => '5'}]} }
      let(:absolute_placeholder) { {'data' => [{'name' => '/absolute_placeholder', 'value' => 'I am absolute', 'id' => '6'}]} }
      let(:hash_placeholder) { {'data' => [{'name' => "#{prepend_provider_namespace('cert_placeholder')}", 'value' => {'cat' => 'meow', 'dog' => 'woof'}, 'id' => '7'}]} }

      let(:mock_config_store) do
        {
          prepend_provider_namespace('integer_placeholder') => generate_success_response(integer_placeholder.to_json),
          prepend_provider_namespace('cert_placeholder') => generate_success_response(cert_placeholder.to_json),
          prepend_provider_namespace('nil_placeholder') => generate_success_response(nil_placeholder.to_json),
          prepend_provider_namespace('empty_placeholder') => generate_success_response(empty_placeholder.to_json),
          prepend_provider_namespace('string_placeholder') => generate_success_response(string_placeholder.to_json),
          '/absolute_placeholder' => generate_success_response(absolute_placeholder.to_json),
          prepend_provider_namespace('hash_placeholder') => generate_success_response(hash_placeholder.to_json)
        }
      end

      let(:links_properties_spec) do
        {
          'age' => '((integer_placeholder))',
          'hash_value' => '((cert_placeholder))',
          'dots_allowed' => '((hash_placeholder.cat))',
          'nil_allowed' => '((nil_placeholder))',
          'empty_allowed' => '((empty_placeholder))',
          'nested_allowed' => {
            'level_1' => '((!string_placeholder))'
          },
          'absolute_allowed' => '((/absolute_placeholder))'
        }
      end

      let(:interpolated_links_properties_spec) do
        {
          'age' => 123,
          'hash_value' => {'ca' => 'ca_value', 'private_key' => 'abc123'},
          'dots_allowed' => 'meow',
          'nil_allowed' => nil,
          'empty_allowed' => '',
          'nested_allowed' => {
            'level_1' => 'test1'
          },
          'absolute_allowed' => 'I am absolute'
        }
      end

      let(:consumer_deployment_name) { 'consumer_deployment_name' }
      let(:provider_deployment_name) { 'provider_deployment_name' }

      let(:consumer_deployment) { instance_double(Bosh::Director::Models::Deployment) }
      let(:provider_deployment) { instance_double(Bosh::Director::Models::Deployment) }

      let(:consumer_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }
      let(:provider_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }

      before do
        allow(consumer_deployment).to receive(:name).and_return(consumer_deployment_name)
        allow(provider_deployment).to receive(:name).and_return(provider_deployment_name)
        allow(consumer_variable_set).to receive(:deployment).and_return(consumer_deployment)
        allow(provider_variable_set).to receive(:deployment).and_return(provider_deployment)
      end

      context 'when links spec passed is nil' do
        it 'returns it as nil' do
          actual_interpolated_link_spec = client.interpolate_cross_deployment_link(nil, consumer_variable_set, provider_variable_set)
          expect(actual_interpolated_link_spec).to be_nil
        end
      end

      context 'when links spec passed is not a hash' do
        it 'throws an error' do
          expect {
            client.interpolate_cross_deployment_link('vroooom', consumer_variable_set, provider_variable_set)
          }.to raise_error "Unable to interpolate cross deployment link properties. Expected a 'Hash', got 'String'"
        end
      end

      context 'when links spec passed is a hash' do
        context 'when the consumer variable_set already has all the variables' do
          before do
            mock_config_store.each do |name, value|
              result_data = JSON.parse(value.body)['data'][0]
              variable_id = result_data['id']

              variable_model = instance_double(Bosh::Director::Models::Variable)
              allow(variable_model).to receive(:variable_name).and_return(name)
              allow(variable_model).to receive(:variable_id).and_return(variable_id)
              allow(consumer_variable_set).to receive(:find_provided_variable_by_name).with(name, provider_deployment_name).and_return(variable_model)

              allow(http_client).to receive(:get_by_id).with(variable_id).and_return(generate_success_response(result_data.to_json))
            end
          end

          it 'fetches the value from the config server with correct ID and return the interpolated hash' do
            actual_interpolated_link_spec = client.interpolate_cross_deployment_link(links_properties_spec, consumer_variable_set, provider_variable_set)
            expect(actual_interpolated_link_spec).to eq(interpolated_links_properties_spec)
            expect(actual_interpolated_link_spec).to_not equal(interpolated_links_properties_spec)
          end

          context 'when an error occurs while requesting values from config server' do
            before do
              mock_config_store.each do |_, value|
                result_data = JSON.parse(value.body)['data'][0]
                variable_id = result_data['id']

                allow(http_client).to receive(:get_by_id).with(variable_id).and_return(SampleNotFoundResponse.new)
              end
            end

            it 'returns a formatted error message' do
              expected_error_msg = <<-EXPECTED.strip
- Failed to find variable '/smurf_director_name/provider_deployment_name/integer_placeholder' with id '1' from config server: HTTP code '404'
- Failed to find variable '/smurf_director_name/provider_deployment_name/cert_placeholder' with id '2' from config server: HTTP code '404'
- Failed to find variable '/smurf_director_name/provider_deployment_name/hash_placeholder' with id '7' from config server: HTTP code '404'
- Failed to find variable '/smurf_director_name/provider_deployment_name/nil_placeholder' with id '3' from config server: HTTP code '404'
- Failed to find variable '/smurf_director_name/provider_deployment_name/empty_placeholder' with id '4' from config server: HTTP code '404'
- Failed to find variable '/smurf_director_name/provider_deployment_name/string_placeholder' with id '5' from config server: HTTP code '404'
- Failed to find variable '/absolute_placeholder' with id '6' from config server: HTTP code '404'
              EXPECTED

              expect {
                client.interpolate_cross_deployment_link(links_properties_spec, consumer_variable_set, provider_variable_set)
              }.to raise_error { |e|
                expect(e.message).to eq(expected_error_msg)
              }
            end
          end
        end

        context 'when the consumer variable_set does not have all the variables' do

          context 'when consumer variable set is NOT writable' do
            before do
              allow(consumer_variable_set).to receive(:writable).and_return(false)

              mock_config_store.each do |name, _|
                allow(consumer_variable_set).to receive(:find_provided_variable_by_name).with(name, provider_deployment_name).and_return(nil)
              end
            end

            it 'should raise an exception with formatted error messages' do
              expected_error_msg = <<-EXPECTED.strip
- Expected variable '/smurf_director_name/provider_deployment_name/integer_placeholder' to be already versioned in deployment 'consumer_deployment_name'
- Expected variable '/smurf_director_name/provider_deployment_name/cert_placeholder' to be already versioned in deployment 'consumer_deployment_name'
- Expected variable '/smurf_director_name/provider_deployment_name/hash_placeholder' to be already versioned in deployment 'consumer_deployment_name'
- Expected variable '/smurf_director_name/provider_deployment_name/nil_placeholder' to be already versioned in deployment 'consumer_deployment_name'
- Expected variable '/smurf_director_name/provider_deployment_name/empty_placeholder' to be already versioned in deployment 'consumer_deployment_name'
- Expected variable '/smurf_director_name/provider_deployment_name/string_placeholder' to be already versioned in deployment 'consumer_deployment_name'
- Expected variable '/absolute_placeholder' to be already versioned in deployment 'consumer_deployment_name'
              EXPECTED

              expect {
                client.interpolate_cross_deployment_link(links_properties_spec, consumer_variable_set, provider_variable_set)
              }.to raise_error { |e|
                expect(e.message).to eq(expected_error_msg)
              }
            end
          end

          context 'when consumer variable set is writable' do
            before do
              allow(consumer_variable_set).to receive(:writable).and_return(true)
            end

            context 'when the provider variable set has the variable' do
              before do
                mock_config_store.each do |name, value|
                  result_data = JSON.parse(value.body)['data'][0]
                  variable_id = result_data['id']

                  variable_model = instance_double(Bosh::Director::Models::Variable)
                  allow(variable_model).to receive(:variable_name).and_return(name)
                  allow(variable_model).to receive(:variable_id).and_return(variable_id)

                  allow(consumer_variable_set).to receive(:find_provided_variable_by_name).with(name, provider_deployment_name).and_return(nil)
                  # expecting here because we can !
                  expect(consumer_variable_set).to receive(:add_variable).with({variable_name:name, variable_id: variable_id, is_local: false, provider_deployment: provider_deployment_name})
                  allow(provider_variable_set).to receive(:find_variable_by_name).with(name).and_return(variable_model)

                  allow(http_client).to receive(:get_by_id).with(variable_id).and_return(generate_success_response(result_data.to_json))
                end
              end

              it 'should copy the variable to the consumer variable set and fetches the values from config server' do
                actual_interpolated_link_spec = client.interpolate_cross_deployment_link(links_properties_spec, consumer_variable_set, provider_variable_set)
                expect(actual_interpolated_link_spec).to eq(interpolated_links_properties_spec)
              end

              context 'when the consumer variable_set throws unique constraint violation while copying variable to it (concurrency possibility)' do
                before do
                  allow(consumer_variable_set).to receive(:add_variable)
                                                    .with({
                                                            variable_name: '/smurf_director_name/provider_deployment_name/string_placeholder',
                                                            variable_id: '5',
                                                            is_local: false,
                                                            provider_deployment: provider_deployment_name
                                                          })
                                                    .and_raise(Sequel::UniqueConstraintViolation.new)
                  allow(consumer_variable_set).to receive(:id).and_return('my_id')
                end

                it 'should catch the exception, log a debug message, and interpolates as correctly' do
                  expect(logger).to receive(:debug).with("Variable '/smurf_director_name/provider_deployment_name/string_placeholder' was already added to consumer variable set 'my_id'")
                  expect {
                    actual_interpolated_link_spec = client.interpolate_cross_deployment_link(links_properties_spec, consumer_variable_set, provider_variable_set)
                    expect(actual_interpolated_link_spec).to eq(interpolated_links_properties_spec)
                  }.to_not raise_error
                end
              end
            end

            context 'when the provider variable set does NOT have the variable' do
              before do
                mock_config_store.each do |name, value|
                  allow(consumer_variable_set).to receive(:find_provided_variable_by_name).with(name, provider_deployment_name).and_return(nil)
                  allow(provider_variable_set).to receive(:find_variable_by_name).with(name).and_return(nil)
                end
              end

              it 'should raise an exception' do
                expected_error_msg = <<-EXPECTED.strip
- Expected variable '/smurf_director_name/provider_deployment_name/integer_placeholder' to be already versioned in link provider deployment 'provider_deployment_name'
- Expected variable '/smurf_director_name/provider_deployment_name/cert_placeholder' to be already versioned in link provider deployment 'provider_deployment_name'
- Expected variable '/smurf_director_name/provider_deployment_name/hash_placeholder' to be already versioned in link provider deployment 'provider_deployment_name'
- Expected variable '/smurf_director_name/provider_deployment_name/nil_placeholder' to be already versioned in link provider deployment 'provider_deployment_name'
- Expected variable '/smurf_director_name/provider_deployment_name/empty_placeholder' to be already versioned in link provider deployment 'provider_deployment_name'
- Expected variable '/smurf_director_name/provider_deployment_name/string_placeholder' to be already versioned in link provider deployment 'provider_deployment_name'
- Expected variable '/absolute_placeholder' to be already versioned in link provider deployment 'provider_deployment_name'
                EXPECTED

                expect {
                  client.interpolate_cross_deployment_link(links_properties_spec, consumer_variable_set, provider_variable_set)
                }.to raise_error { |e|
                  expect(e.message).to eq(expected_error_msg)
                }
              end
            end
          end
        end
      end
    end

    describe '#prepare_and_get_property' do
      let(:ok_response) do
        response = SampleSuccessResponse.new
        response.body = {
          :data => [
            :id => 'whateverid',
            :name => 'whatevername',
            :value => 'hello',
          ]
        }.to_json
        response
      end

      context 'when property value provided is nil' do
        it 'returns default value' do
          expect(client.prepare_and_get_property(nil, 'my_default_value', 'some_type', deployment_name)).to eq('my_default_value')
        end
      end

      context 'when property value is NOT nil' do
        context 'when property value is NOT a full placeholder (NOT padded with brackets)' do
          it 'returns that property value' do
            expect(client.prepare_and_get_property('my_smurf', 'my_default_value', nil, deployment_name)).to eq('my_smurf')
            expect(client.prepare_and_get_property('((my_smurf', 'my_default_value', nil, deployment_name)).to eq('((my_smurf')
            expect(client.prepare_and_get_property('my_smurf))', 'my_default_value', 'whatever', deployment_name)).to eq('my_smurf))')
            expect(client.prepare_and_get_property('((my_smurf))((vroom))', 'my_default_value', 'whatever', deployment_name)).to eq('((my_smurf))((vroom))')
            expect(client.prepare_and_get_property('((my_smurf)) i am happy', 'my_default_value', 'whatever', deployment_name)).to eq('((my_smurf)) i am happy')
            expect(client.prepare_and_get_property('this is ((smurf_1)) this is ((smurf_2))', 'my_default_value', 'whatever', deployment_name)).to eq('this is ((smurf_1)) this is ((smurf_2))')
          end
        end

        context 'when property value is a FULL placeholder (padded with brackets)' do
          context 'when placeholder syntax is invalid' do
            it 'raises an error' do
              expect {
                client.prepare_and_get_property('((invalid name $%$^))', 'my_default_value', nil, deployment_name)
              }.to raise_error(Bosh::Director::ConfigServerIncorrectNameSyntax)
            end
          end

          context 'when placeholder syntax is valid' do
            let(:the_placeholder) { '((my_smurf))' }
            let(:bang_placeholder) { '((!my_smurf))' }

            context 'when config server returns an error while checking for name' do
              it 'raises an error' do
                expect(http_client).to receive(:get).with(prepend_namespace('my_smurf')).and_return(SampleForbiddenResponse.new)
                expect {
                  client.prepare_and_get_property(the_placeholder, 'my_default_value', nil, deployment_name)
                }.to raise_error(Bosh::Director::ConfigServerFetchError, "Failed to fetch variable '/smurf_director_name/deployment_name/my_smurf' from config server: HTTP code '403'")
              end
            end

            context 'when value is found in config server' do
              it 'returns that property value as is' do
                expect(http_client).to receive(:get).with(prepend_namespace('my_smurf')).and_return(ok_response)
                expect(client.prepare_and_get_property(the_placeholder, 'my_default_value', nil, deployment_name)).to eq(the_placeholder)
              end

              it 'returns that property value as is when it starts with exclamation mark' do
                expect(http_client).to receive(:get).with(prepend_namespace('my_smurf')).and_return(ok_response)
                expect(client.prepare_and_get_property(bang_placeholder, 'my_default_value', nil, deployment_name)).to eq(bang_placeholder)
              end
            end

            context 'when value is NOT found in config server' do
              before do
                expect(http_client).to receive(:get).with(prepend_namespace('my_smurf')).and_return(SampleNotFoundResponse.new)
              end

              context 'when default is defined' do
                it 'returns the default value when type is nil' do
                  expect(client.prepare_and_get_property(the_placeholder, 'my_default_value', nil, deployment_name)).to eq('my_default_value')
                end

                it 'returns the default value when type is defined' do
                  expect(client.prepare_and_get_property(the_placeholder, 'my_default_value', 'some_type', deployment_name)).to eq('my_default_value')
                end

                it 'returns the default value when type is defined and generatable' do
                  expect(client.prepare_and_get_property(the_placeholder, 'my_default_value', 'password', deployment_name)).to eq('my_default_value')
                end

                context 'when placeholder starts with exclamation mark' do
                  it 'returns the default value when type is nil' do
                    expect(client.prepare_and_get_property(bang_placeholder, 'my_default_value', nil, deployment_name)).to eq('my_default_value')
                  end

                  it 'returns the default value when type is defined' do
                    expect(client.prepare_and_get_property(bang_placeholder, 'my_default_value', 'some_type', deployment_name)).to eq('my_default_value')
                  end

                  it 'returns the default value when type is defined and generatable' do
                    expect(client.prepare_and_get_property(bang_placeholder, 'my_default_value', 'password', deployment_name)).to eq('my_default_value')
                  end
                end
              end

              context 'when default is NOT defined i.e nil' do
                let(:full_key) { prepend_namespace('my_smurf') }
                let(:default_value) { nil }
                let(:type) { 'any-type-you-like' }

                context 'when the release spec property defines a type' do
                  let(:success_response) do
                    result = SampleSuccessResponse.new
                    result.body = {'id'=>858, 'name'=>'/smurf_director_name/deployment_name/my_smurf', 'value'=>'abc'}.to_json
                    result
                  end

                  it 'generates the value, records the event, and returns the user provided placeholder' do
                    expect(http_client).to receive(:post).with({'name' => "#{full_key}", 'type' => 'any-type-you-like', 'parameters' => {}}).and_return(success_response)
                    expect(client.prepare_and_get_property(the_placeholder, default_value, type, deployment_name)).to eq(the_placeholder)
                    expect(Bosh::Director::Models::Event.count).to eq(1)

                    recorded_event = Bosh::Director::Models::Event.first
                    expect(recorded_event.user).to eq('user')
                    expect(recorded_event.action).to eq('create')
                    expect(recorded_event.object_type).to eq('variable')
                    expect(recorded_event.object_name).to eq('/smurf_director_name/deployment_name/my_smurf')
                    expect(recorded_event.task).to eq("#{task_id}")
                    expect(recorded_event.deployment).to eq(deployment_name)
                    expect(recorded_event.instance).to eq(nil)
                    expect(recorded_event.context).to eq({'id'=>858, 'name'=>'/smurf_director_name/deployment_name/my_smurf'})
                  end

                  context 'when config server throws an error while generating' do
                    before do
                      allow(http_client).to receive(:post).with({'name' => "#{full_key}", 'type' => 'any-type-you-like', 'parameters' => {}}).and_return(SampleForbiddenResponse.new)
                    end

                    it 'throws an error and record and event' do
                      expect(logger).to receive(:error)
                      expect{
                        client.prepare_and_get_property(the_placeholder, default_value, type, deployment_name)
                      }. to raise_error(
                              Bosh::Director::ConfigServerGenerationError,
                              "Config Server failed to generate value for '#{full_key}' with type 'any-type-you-like'. Error: 'There was a problem.'"
                            )

                      expect(Bosh::Director::Models::Event.count).to eq(1)

                      error_event = Bosh::Director::Models::Event.first
                      expect(error_event.user).to eq('user')
                      expect(error_event.action).to eq('create')
                      expect(error_event.object_type).to eq('variable')
                      expect(error_event.object_name).to eq('/smurf_director_name/deployment_name/my_smurf')
                      expect(error_event.task).to eq("#{task_id}")
                      expect(error_event.deployment).to eq(deployment_name)
                      expect(error_event.context).to eq({})
                      expect(error_event.error).to eq("Config Server failed to generate value for '/smurf_director_name/deployment_name/my_smurf' with type 'any-type-you-like'. Error: 'There was a problem.'")
                    end
                  end

                  it 'should save generated variable to variable_mappings table' do
                    allow(http_client).to receive(:post).and_return(success_post_response)
                    expect(Bosh::Director::Models::Variable[variable_name: prepend_namespace('my_smurf'), variable_set_id: variables_set_id]).to be_nil

                    client.prepare_and_get_property(the_placeholder, default_value, type, deployment_name)

                    saved_variable = Bosh::Director::Models::Variable[variable_name: prepend_namespace('my_smurf'), variable_set_id: variables_set_id]
                    expect(saved_variable.variable_name).to eq(prepend_namespace('my_smurf'))
                    expect(saved_variable.variable_id).to eq('some_id1')
                  end

                  it 'should raise an error when id is not present in generated  response' do
                    allow(http_client).to receive(:post).and_return(generate_success_response({value: 'some-foo'}.to_json))

                    expect{
                      client.prepare_and_get_property(the_placeholder, default_value, type, deployment_name)
                    }.to raise_error(
                           Bosh::Director::ConfigServerGenerationError,
                           "Failed to version generated variable '#{prepend_namespace('my_smurf')}'. Expected Config Server response to have key 'id'"
                    )

                  end

                  context 'when placeholder starts with exclamation mark' do
                    it 'generates the value and returns the user provided placeholder' do
                      expect(http_client).to receive(:post).with({'name' => "#{full_key}", 'type' => 'any-type-you-like', 'parameters' => {}}).and_return(success_post_response)
                      expect(client.prepare_and_get_property(bang_placeholder, default_value, type, deployment_name)).to eq(bang_placeholder)
                    end
                  end

                  context 'when type is certificate' do
                    let(:full_key) { prepend_namespace('my_smurf') }
                    let(:type) { 'certificate' }
                    let(:dns_record_names) do
                      %w(*.fake-name1.network-a.simple.bosh *.fake-name1.network-b.simple.bosh)
                    end

                    let(:options) do
                      {
                        :dns_record_names => dns_record_names
                      }
                    end

                    let(:post_body) do
                      {
                        'name' => full_key,
                        'type' => 'certificate',
                        'parameters' => {
                          'common_name' => dns_record_names[0],
                          'alternative_names' => dns_record_names
                        }
                      }
                    end

                    it 'generates a certificate and returns the user provided placeholder' do
                      expect(http_client).to receive(:post).with(post_body).and_return(success_post_response)
                      expect(client.prepare_and_get_property(the_placeholder, default_value, type, deployment_name, options)).to eq(the_placeholder)
                    end

                    it 'generates a certificate and returns the user provided placeholder even with dots' do
                      dotted_placeholder = '((my_smurf.ca))'
                      expect(http_client).to receive(:post).with(post_body).and_return(success_post_response)
                      expect(client.prepare_and_get_property(dotted_placeholder, default_value, type, deployment_name, options)).to eq(dotted_placeholder)
                    end

                    it 'generates a certificate and returns the user provided placeholder even if nested' do
                      dotted_placeholder = '((my_smurf.ca.fingerprint))'
                      expect(http_client).to receive(:post).with(post_body).and_return(success_post_response)
                      expect(client.prepare_and_get_property(dotted_placeholder, default_value, type, deployment_name, options)).to eq(dotted_placeholder)
                    end

                    it 'throws an error if generation of certficate errors' do
                      expect(http_client).to receive(:post).with(post_body).and_return(SampleForbiddenResponse.new)
                      expect(logger).to receive(:error)

                      expect {
                        client.prepare_and_get_property(the_placeholder, default_value, type, deployment_name, options)
                      }.to raise_error(
                             Bosh::Director::ConfigServerGenerationError,
                             "Config Server failed to generate value for '#{full_key}' with type 'certificate'. Error: 'There was a problem.'"
                           )
                    end

                    context 'when placeholder starts with exclamation mark' do
                      it 'generates a certificate and returns the user provided placeholder' do
                        expect(http_client).to receive(:post).with(post_body).and_return(success_post_response)
                        expect(client.prepare_and_get_property(bang_placeholder, default_value, type, deployment_name, options)).to eq(bang_placeholder)
                      end
                    end
                  end

                  context 'but variable set is not writable' do
                    let(:deployment_lookup){ instance_double(Bosh::Director::Api::DeploymentLookup) }
                    let(:deployment_model) { instance_double(Bosh::Director::Models::Deployment) }
                    let(:variable_set) { instance_double(Bosh::Director::Models::VariableSet) }

                    before do
                      allow(http_client).to receive(:post).and_return(success_post_response)
                      allow(Bosh::Director::Api::DeploymentLookup).to receive(:new).and_return(deployment_lookup)
                      allow(deployment_lookup).to receive(:by_name).and_return(deployment_model)
                      allow(deployment_model).to receive(:current_variable_set).and_return(variable_set)
                      allow(variable_set).to receive(:writable).and_return(false)
                    end

                    it 'should raise an error' do
                      models = Bosh::Director::Models::Variable.all

                      expect(models.length).to eq(0)
                      expect{
                        client.prepare_and_get_property(the_placeholder, default_value, type, deployment_name)
                      }.to raise_error(Bosh::Director::ConfigServerGenerationError, "Variable '#{prepend_namespace('my_smurf')}' cannot be generated. Variable generation allowed only during deploy action")
                      expect(models.length).to eq(0)
                    end
                  end

                end

                context 'when the release spec property does NOT define a type' do
                  let(:type) { nil }
                  it 'returns that the user provided value as is' do
                    expect(client.prepare_and_get_property(the_placeholder, default_value, type, deployment_name)).to eq(the_placeholder)
                  end
                end
              end
            end
          end
        end
      end
    end

    describe '#generate_values' do
      context 'when given a variables object' do
        context 'when some variable names syntax are NOT correct' do
          let(:variable_specs_list) do
            [
              [{'name' => 'p*laceholder_a', 'type' => 'password'}],
              [{'name' => 'placeholder_a/', 'type' => 'password'}],
              [{'name' => '', 'type' => 'password'}],
              [{'name' => ' ', 'type' => 'password'}],
              [{'name' => '((vroom))', 'type' => 'password'}],
            ]
          end

          it 'should throw an error and log it' do
            variable_specs_list.each do |variables_spec|
              expect {
                client.generate_values(Bosh::Director::DeploymentPlan::Variables.new(variables_spec), deployment_name)
              }.to raise_error Bosh::Director::ConfigServerIncorrectNameSyntax
            end
          end
        end

        context 'when ALL variable names syntax are correct' do
          let(:variables_spec) do
            [
              {'name' => 'placeholder_a', 'type' => 'password'},
              {'name' => 'placeholder_b', 'type' => 'certificate', 'options' => {'common_name' => 'bosh.io', 'alternative_names' => ['a.bosh.io', 'b.bosh.io']}},
              {'name' => '/placeholder_c', 'type' => 'gold', 'options' => {'need' => 'luck'}}
            ]
          end

          let(:variables_obj) do
            Bosh::Director::DeploymentPlan::Variables.new(variables_spec)
          end

          it 'should generate all the variables in order' do
            expect(http_client).to receive(:post).with(
              {
                'name' => prepend_namespace('placeholder_a'),
                'type' => 'password',
                'parameters' => {}
              }
            ).ordered.and_return(
              generate_success_response(
                {
                  "id": "some_id1",
                }.to_json)
            )

            expect(http_client).to receive(:post).with(
              {
                'name' => prepend_namespace('placeholder_b'),
                'type' => 'certificate',
                'parameters' => {'common_name' => 'bosh.io', 'alternative_names' => %w(a.bosh.io b.bosh.io)}
              }
            ).ordered.and_return(
              generate_success_response(
                {
                  "id": "some_id2",
                }.to_json)
            )

            expect(http_client).to receive(:post).with(
              {
                'name' => '/placeholder_c',
                'type' => 'gold',
                'parameters' => {'need' => 'luck'}
              }
            ).ordered.and_return(
              generate_success_response(
                {
                  "id": "some_id3",
                }.to_json)
            )

            client.generate_values(variables_obj, deployment_name)
          end

          it 'should save generated variables to variable table with correct associations' do
            allow(http_client).to receive(:post).and_return(
              generate_success_response({'id': 'some_id1'}.to_json),
              generate_success_response({'id': 'some_id2'}.to_json),
              generate_success_response({'id': 'some_id3'}.to_json),
            )

            expect(Bosh::Director::Models::Variable[variable_id: 'some_id1', variable_name: prepend_namespace('placeholder_a'), variable_set_id: variables_set_id]).to be_nil
            expect(Bosh::Director::Models::Variable[variable_id: 'some_id2', variable_name: prepend_namespace('placeholder_b'), variable_set_id: variables_set_id]).to be_nil
            expect(Bosh::Director::Models::Variable[variable_id: 'some_id3', variable_name: '/placeholder_c', variable_set_id: variables_set_id]).to be_nil

            client.generate_values(variables_obj, deployment_name)

            expect(Bosh::Director::Models::Variable[variable_id: 'some_id1', variable_name: prepend_namespace('placeholder_a'), variable_set_id: variables_set_id]).to_not be_nil
            expect(Bosh::Director::Models::Variable[variable_id: 'some_id2', variable_name: prepend_namespace('placeholder_b'), variable_set_id: variables_set_id]).to_not be_nil
            expect(Bosh::Director::Models::Variable[variable_id: 'some_id3', variable_name: '/placeholder_c', variable_set_id: variables_set_id]).to_not be_nil
          end

          it 'should record events' do
            success_response_1 = SampleSuccessResponse.new
            success_response_1.body = {'id'=>1, 'name'=>'/smurf_director_name/deployment_name/placeholder_a', 'value'=>'abc'}.to_json

            success_response_2 = SampleSuccessResponse.new
            success_response_2.body = {'id'=>2, 'name'=>'/smurf_director_name/deployment_name/placeholder_b', 'value'=>'my_cert_value'}.to_json

            success_response_3 = SampleSuccessResponse.new
            success_response_3.body = {'id'=>3, 'name'=>'/placeholder_c', 'value'=>'value_3'}.to_json

            expect(http_client).to receive(:post).with(
              {
                'name' => prepend_namespace('placeholder_a'),
                'type' => 'password',
                'parameters' => {}
              }
            ).ordered.and_return(success_response_1)

            expect(http_client).to receive(:post).with(
              {
                'name' => prepend_namespace('placeholder_b'),
                'type' => 'certificate',
                'parameters' => {'common_name' => 'bosh.io', 'alternative_names' => %w(a.bosh.io b.bosh.io)}
              }
            ).ordered.and_return(success_response_2)

            expect(http_client).to receive(:post).with(
              {
                'name' => '/placeholder_c',
                'type' => 'gold',
                'parameters' => { 'need' => 'luck' }
              }
            ).ordered.and_return(success_response_3)

            expect {
              client.generate_values(variables_obj, deployment_name)
            }.to change { Bosh::Director::Models::Event.count }.from(0).to(3)

            event_1 = Bosh::Director::Models::Event.first
            expect(event_1.user).to eq('user')
            expect(event_1.action).to eq('create')
            expect(event_1.object_type).to eq('variable')
            expect(event_1.object_name).to eq('/smurf_director_name/deployment_name/placeholder_a')
            expect(event_1.task).to eq("#{task_id}")
            expect(event_1.deployment).to eq(deployment_name)
            expect(event_1.instance).to eq(nil)
            expect(event_1.context).to eq({'id'=>1,'name'=>'/smurf_director_name/deployment_name/placeholder_a'})

            event_2 = Bosh::Director::Models::Event.order(:id)[2]
            expect(event_2.user).to eq('user')
            expect(event_2.action).to eq('create')
            expect(event_2.object_type).to eq('variable')
            expect(event_2.object_name).to eq('/smurf_director_name/deployment_name/placeholder_b')
            expect(event_2.task).to eq("#{task_id}")
            expect(event_2.deployment).to eq(deployment_name)
            expect(event_2.instance).to eq(nil)
            expect(event_2.context).to eq({'id'=>2,'name'=>'/smurf_director_name/deployment_name/placeholder_b'})

            event_3 = Bosh::Director::Models::Event.order(:id)[3]
            expect(event_3.user).to eq('user')
            expect(event_3.action).to eq('create')
            expect(event_3.object_type).to eq('variable')
            expect(event_3.object_name).to eq('/placeholder_c')
            expect(event_3.task).to eq("#{task_id}")
            expect(event_3.deployment).to eq(deployment_name)
            expect(event_3.instance).to eq(nil)
            expect(event_3.context).to eq({'id'=>3,'name'=>'/placeholder_c'})
          end

          context 'when variable options contains a ca key' do

            context 'when variable type is certificate & ca is relative' do
              let(:variables_spec) do
                [
                    {'name' => 'placeholder_b', 'type' => 'certificate', 'options' => {'ca' => 'my_ca', 'common_name' => 'bosh.io', 'alternative_names' => ['a.bosh.io', 'b.bosh.io']}},
                ]
              end

              let(:variables_obj) do
                Bosh::Director::DeploymentPlan::Variables.new(variables_spec)
              end

              it 'namespaces the ca reference for a variable with type certificate' do
                expect(http_client).to receive(:post).with(
                    {
                        'name' => prepend_namespace('placeholder_b'),
                        'type' => 'certificate',
                        'parameters' => {'ca' => prepend_namespace('my_ca'), 'common_name' => 'bosh.io', 'alternative_names' => %w(a.bosh.io b.bosh.io)}
                    }
                ).ordered.and_return(
                    generate_success_response(
                        {
                            "id": "some_id2",
                        }.to_json))

                client.generate_values(variables_obj, deployment_name)
              end

            end

            context 'when variable type is certificate & ca is absolute' do
              let(:variables_spec) do
                [
                    {'name' => 'placeholder_b', 'type' => 'certificate', 'options' => {'ca' => '/my_ca', 'common_name' => 'bosh.io', 'alternative_names' => ['a.bosh.io', 'b.bosh.io']}},
                ]
              end

              let(:variables_obj) do
                Bosh::Director::DeploymentPlan::Variables.new(variables_spec)
              end

              it 'namespaces the ca reference for a variable with type certificate' do
                expect(http_client).to receive(:post).with(
                    {
                        'name' => prepend_namespace('placeholder_b'),
                        'type' => 'certificate',
                        'parameters' => {'ca' => ('/my_ca'), 'common_name' => 'bosh.io', 'alternative_names' => %w(a.bosh.io b.bosh.io)}
                    }
                ).ordered.and_return(
                    generate_success_response(
                        {
                            "id": "some_id2",
                        }.to_json))

                client.generate_values(variables_obj, deployment_name)
              end

            end

            context 'when variable type is NOT certificate' do
              let(:variables_spec) do
                [
                    {'name' => 'placeholder_a', 'type' => 'something-else','options' => {'ca' => 'some_ca_value'}},
                ]
              end

              let(:variables_obj) do
                Bosh::Director::DeploymentPlan::Variables.new(variables_spec)
              end

              it 'it passes options through to config server without modification' do
                expect(http_client).to receive(:post).with(
                    {
                        'name' => prepend_namespace('placeholder_a'),
                        'type' => 'something-else',
                        'parameters' => {'ca' => 'some_ca_value'}
                    }
                ).ordered.and_return(
                    generate_success_response(
                        {
                            "id": "some_id1",
                        }.to_json))

                client.generate_values(variables_obj, deployment_name)
              end
            end


          end

          context 'when config server throws an error while generating' do
            before do
              allow(http_client).to receive(:post).with(
                {
                  'name' => prepend_namespace('placeholder_a'),
                  'type' => 'password',
                  'parameters' => {}
                }
              ).ordered.and_return(SampleForbiddenResponse.new)
            end

            it 'should throw an error, log it, and record event' do
              expect(logger).to receive(:error)

              expect {
                client.generate_values(variables_obj, deployment_name)
              }.to raise_error(
                     Bosh::Director::ConfigServerGenerationError,
                     "Config Server failed to generate value for '/smurf_director_name/deployment_name/placeholder_a' with type 'password'. Error: 'There was a problem.'"
                   )

              expect(Bosh::Director::Models::Event.count).to eq(1)

              error_event = Bosh::Director::Models::Event.first
              expect(error_event.user).to eq('user')
              expect(error_event.action).to eq('create')
              expect(error_event.object_type).to eq('variable')
              expect(error_event.object_name).to eq('/smurf_director_name/deployment_name/placeholder_a')
              expect(error_event.task).to eq("#{task_id}")
              expect(error_event.deployment).to eq(deployment_name)
              expect(error_event.instance).to eq(nil)
              expect(error_event.error).to eq("Config Server failed to generate value for '/smurf_director_name/deployment_name/placeholder_a' with type 'password'. Error: 'There was a problem.'")
            end
          end

          context 'when config server response is NOT in JSON format' do
            before do
              response = SampleSuccessResponse.new
              response.body = 'NOT JSON!!!'

              allow(http_client).to receive(:post).and_return(response)
            end

            it 'should throw an error and log it' do
              expect(logger).to_not receive(:error)

              expect{
                client.generate_values(variables_obj, deployment_name)
              }.to raise_error(
                     Bosh::Director::ConfigServerGenerationError,
                     "Config Server returned a NON-JSON body while generating value for '/smurf_director_name/deployment_name/placeholder_a' with type 'password'"
                   )
            end
          end

          context 'but variable set is not writable' do
            let(:deployment_lookup){ instance_double(Bosh::Director::Api::DeploymentLookup) }
            let(:deployment_model) { instance_double(Bosh::Director::Models::Deployment) }
            let(:variable_set) { instance_double(Bosh::Director::Models::VariableSet) }

            before do
              allow(Bosh::Director::Api::DeploymentLookup).to receive(:new).and_return(deployment_lookup)
              allow(deployment_lookup).to receive(:by_name).and_return(deployment_model)
              allow(deployment_model).to receive(:current_variable_set).and_return(variable_set)
              allow(variable_set).to receive(:writable).and_return(false)
            end

            it 'should raise an error' do
              models = Bosh::Director::Models::Variable.all

              expect(models.length).to eq(0)
              expect{
                client.generate_values(variables_obj, deployment_name)
              }.to raise_error(Bosh::Director::ConfigServerGenerationError, "Variable '#{prepend_namespace('placeholder_a')}' cannot be generated. Variable generation allowed only during deploy action")
              expect(models.length).to eq(0)
            end
          end


        end
      end
    end

    def generate_success_response(body)
      result = SampleSuccessResponse.new
      result.body = body
      result
    end
  end

  describe DisabledClient do
    subject(:disabled_client) { DisabledClient.new }
    let(:deployment_name) { 'smurf_deployment' }

    it 'responds to all methods of EnabledClient and vice versa' do
      expect(EnabledClient.instance_methods - DisabledClient.instance_methods).to be_empty
      expect(DisabledClient.instance_methods - EnabledClient.instance_methods).to be_empty
    end

    it 'has the same arity as EnabledClient methods' do
      EnabledClient.instance_methods.each do |method_name|
        expect(EnabledClient.instance_method(method_name).arity).to eq(DisabledClient.instance_method(method_name).arity)
      end
    end

    describe '#interpolate' do
      let(:src) do
        {
          'test' => 'smurf',
          'test2' => '((placeholder))'
        }
      end

      it 'returns src as is' do
        expect(disabled_client.interpolate(src)).to eq(src)
      end
    end

    describe '#interpolate_with_versioning' do
      let(:src) do
        {
          'test' => 'smurf',
          'test2' => '((placeholder))'
        }
      end
      let(:variable_set) { instance_double(Bosh::Director::Models::VariableSet)}

      it 'returns src as is' do
        expect(disabled_client.interpolate_with_versioning(src, variable_set)).to eq(src)
      end
    end

    describe '#interpolate_cross_deployment_link' do
      let(:link_spec) do
        {
          'test' => 'smurf',
          'test2' => '((placeholder))'
        }
      end

      let(:consumer_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }
      let(:provider_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }

      it 'returns src as is' do
        expect(disabled_client.interpolate_cross_deployment_link(link_spec, consumer_variable_set, provider_variable_set)).to eq(link_spec)
      end
    end

    describe '#prepare_and_get_property' do
      it 'returns manifest property value if defined' do
        expect(disabled_client.prepare_and_get_property('provided prop', 'default value is here', nil, deployment_name)).to eq('provided prop')
        expect(disabled_client.prepare_and_get_property('provided prop', 'default value is here', nil, deployment_name, {})).to eq('provided prop')
        expect(disabled_client.prepare_and_get_property('provided prop', 'default value is here', nil, deployment_name, {'whatever' => 'hello'})).to eq('provided prop')
      end
      it 'returns default value when manifest value is nil' do
        expect(disabled_client.prepare_and_get_property(nil, 'default value is here', nil, deployment_name)).to eq('default value is here')
        expect(disabled_client.prepare_and_get_property(nil, 'default value is here', nil, deployment_name, {})).to eq('default value is here')
        expect(disabled_client.prepare_and_get_property(nil, 'default value is here', nil, deployment_name, {'whatever' => 'hello'})).to eq('default value is here')
      end
    end

    describe '#generate_values' do
      it 'exists' do
        expect { disabled_client.generate_values(anything, anything) }.to_not raise_error
      end
    end
  end

  class SampleSuccessResponse < Net::HTTPOK
    attr_accessor :body

    def initialize
      super(nil, '200', nil)
    end
  end

  class SampleNotFoundResponse < Net::HTTPNotFound
    def initialize
      super(nil, '404', 'Not Found Brah')
    end
  end

  class SampleForbiddenResponse < Net::HTTPForbidden
    def initialize
      super(nil, '403', 'There was a problem.')
    end
  end
end
