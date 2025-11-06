require 'spec_helper'

module Bosh::Director::ConfigServer
  describe ConfigServerClient do
    subject(:client) { ConfigServerClient.new(http_client, director_name, logger) }
    let(:director_name) { 'smurf_director_name' }
    let(:deployment_name) { 'deployment_name' }
    let(:logger) { double('Logging::Logger') }
    let(:variables_set_id) { 2000 }
    let(:success_post_response) do
      generate_success_response({ id: 'some_id1' }.to_json)
    end
    let(:http_client) { double('Bosh::Director::ConfigServer::HTTPClient') }

    let(:event_manager) { Bosh::Director::Api::EventManager.new(true) }
    let(:task_id) { 42 }
    let(:update_job) { instance_double(Bosh::Director::Jobs::UpdateDeployment, username: 'user', task_id: task_id, event_manager: event_manager) }

    let(:success_response) do
      result = SampleSuccessResponse.new
      result.body = { 'id' => 504 }.to_json
      result
    end

    let(:deployment_model) { FactoryBot.create(:models_deployment, name: deployment_name) }

    def prepend_namespace(name)
      "/#{director_name}/#{deployment_name}/#{name}"
    end

    before do
      FactoryBot.create(:models_variable_set, id: variables_set_id, deployment: deployment_model, writable: true)

      allow(logger).to receive(:info)
      allow(Bosh::Director::Config).to receive(:current_job).and_return(update_job)
    end

    describe '#interpolate' do
      let(:deployment_name) { 'my_deployment_name' }
      let(:raw_hash) do
        {
          'properties' => {
            'integer_allowed' => '((/integer_placeholder))',
            'nil_allowed' => '((/nil_placeholder))',
            'empty_allowed' => '((/empty_placeholder))',
          },
          'i_am_a_hash' => {
            'i_am_an_array' => [
              {
                'name' => 'test_job',
                'properties' => { 'job_prop' => '((/string_placeholder))' },
              },
            ],
          },
          'i_am_another_array' => [
            { 'env' => { 'env_prop' => '((/hash_placeholder))' } },
          ],
          'my_value_will_be_a_hash' => '((/hash_placeholder))',
        }
      end
      let(:interpolated_hash) do
        {
          'properties' => {
            'integer_allowed' => 123,
            'nil_allowed' => nil,
            'empty_allowed' => '',
          },
          'i_am_a_hash' => {
            'i_am_an_array' => [
              {
                'name' => 'test_job',
                'properties' => { 'job_prop' => 'i am a string' },
              },
            ],
          },
          'i_am_another_array' => [
            { 'env' => { 'env_prop' => hash_placeholder_value } },
          ],
          'my_value_will_be_a_hash' => hash_placeholder_value,
        }
      end
      let(:hash_placeholder_value) do
        {
          'ca' => {
            'level_1' => 'level_1_value',
            'level_2' => {
              'level_2_1' => 'level_2_1_value',
            },
          },
          'private_key' => 'abc123',
        }
      end

      before do
        allow(deployment_model).to receive(:name).and_return(deployment_name)
      end

      context 'when object to be interpolated is NOT nil' do
        context 'when object to be interpolated is a hash' do
          context 'when hash does NOT contain any placeholders' do
            let(:raw_hash) do
              {
                'properties' => {
                  'integer_allowed' => '1',
                  'nil_allowed' => nil,
                  'empty_allowed' => '',
                },
                'i_am_a_hash' => {
                  'i_am_an_array' => [
                    {
                      'name' => 'test_job',
                      'properties' => { 'job_prop' => 'string' },
                    },
                  ],
                },
                'i_am_another_array' => [
                  { 'env' => { 'env_prop' => {} } },
                ],
                'my_value_will_be_a_hash' => {},
              }
            end

            it 'does not raise an error' do
              expect do
                client.interpolate(raw_hash)
              end.to_not raise_error
            end

            it 'returns an equivalent hash' do
              interpolated_hash = client.interpolate(raw_hash)
              expect(interpolated_hash).to eq(raw_hash)
            end
          end

          context 'when all placeholders syntax is correct' do
            let(:integer_placeholder) do
              { 'data' => [{ 'name' => prepend_namespace('integer_placeholder').to_s, 'value' => 123, 'id' => '1' }] }
            end
            let(:nil_placeholder) do
              { 'data' => [{ 'name' => prepend_namespace('nil_placeholder').to_s, 'value' => nil, 'id' => '2' }] }
            end
            let(:empty_placeholder) do
              { 'data' => [{ 'name' => prepend_namespace('empty_placeholder').to_s, 'value' => '', 'id' => '3' }] }
            end
            let(:string_placeholder) do
              { 'data' => [{ 'name' => prepend_namespace('string_placeholder').to_s, 'value' => 'i am a string', 'id' => '4' }] }
            end
            let(:hash_placeholder) do
              {
                'data' => [
                  {
                    'name' => prepend_namespace('hash_placeholder').to_s,
                    'value' => hash_placeholder_value,
                    'id' => '5',
                  },
                ],
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

            let(:response_body_id) do
              { 'name' => variable_name, 'value' => variable_value, 'id' => variable_id }
            end
            let(:response_body_name) do
              { 'data' => [response_body_id] }
            end
            let(:mock_response) { generate_success_response(response_body_name.to_json) }

            before do
              mock_config_store.each do |name, value|
                result_body = JSON.parse(value.body)
                allow(http_client).to receive(:get).with(name).and_return(generate_success_response(result_body.to_json))
              end
              allow(http_client).to receive(:get).with('/boo').and_return(mock_response)
            end

            it 'should use the latest variables from the config server' do
              result = client.interpolate('key' => "((#{variable_name}))")
              expect(result['key']).to eq('var_val')
            end

            context 'when variable does not use an absolute name' do
              let(:variable_name) { 'boo' }

              it 'should error' do
                expect do
                  client.interpolate('key' => "((#{variable_name}))")
                end.to raise_error Bosh::Director::ConfigServerIncorrectNameSyntax
              end
            end

            context 'when a variable has sub-keys' do
              let(:variable_value) do
                { 'cert' => 'my cert', 'key' => 'my key', 'ca' => 'my ca' }
              end

              it 'should get the sub-value as needed' do
                result = client.interpolate('key' => '((/boo.ca))')
                expect(result['key']).to eq('my ca')
              end
            end

            context 'when response received from server is not in the expected format' do
              let(:manifest_hash) do
                {
                  'name' => 'deployment_name',
                  'properties' => {
                    'name' => '((/bad))',
                  },
                }
              end

              [
                { 'response' => 'Invalid JSON response',
                  'message' => '- Failed to fetch variable \'/bad\' from config server: Invalid JSON response' },

                { 'response' => '{"x" : {}}',
                  'message' => '- Failed to fetch variable \'/bad\' from config server: Expected data to be an array' },

                { 'response' => '{"data" : {"value" : "x"}}',
                  'message' => '- Failed to fetch variable \'/bad\' from config server: Expected data to be an array' },

                { 'response' => '{"data" : []}',
                  'message' => '- Failed to fetch variable \'/bad\' from config server: Expected data to be non empty array' },

                { 'response' => '{"data" : [{"name" : "name1", "id" : "id1", "val" : "x"}]}',
                  'message' => '- Failed to fetch variable \'/bad\' from config server: Expected data[0] to have key \'value\'' },

                { 'response' => '{"data" : [{"name" : "name1", "value" : "x"}]}',
                  'message' => '- Failed to fetch variable \'/bad\' from config server: Expected data[0] to have key \'id\'' },
              ].each do |entry|
                it 'raises an error' do
                  allow(http_client).to receive(:get).with('/bad').and_return(generate_success_response(entry['response']))
                  expect do
                    client.interpolate(manifest_hash)
                  end.to raise_error Bosh::Director::ConfigServerFetchError, entry['message']
                end
              end
            end

            context 'when name is not found in the config_server' do
              let(:manifest_hash) do
                {
                  'name' => 'deployment_name',
                  'properties' => {
                    'name' => '((/missing_placeholder))',
                  },
                }
              end

              it 'should raise a missing name error message' do
                allow(http_client).to receive(:get).with('/missing_placeholder').and_return(SampleNotFoundResponse.new)

                expect do
                  client.interpolate(manifest_hash)
                end.to(raise_error { |error|
                  expect(error).to be_a(Bosh::Director::ConfigServerFetchError)
                  expect(error.message).to include("- Failed to find variable '/missing_placeholder' from config server: HTTP Code '404', Error: 'Name not found'")
                })
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
                  expect do
                    client.interpolate(raw_hash)
                  end.to raise_error("- Failed to fetch variable '/hash_placeholder' " \
                                     "from config server: Expected parent '/hash_placeholder.ca' hash to have key 'level_n'")
                end
              end

              context 'when multiple errors occur because parts of dot syntax is not found' do
                before do
                  raw_hash['my_value_will_be_a_hash'] = '((/hash_placeholder.ca.level_n.level_n_1))'
                  raw_hash['my_value_will_be_an_other_hash'] = '((/hash_placeholder.ca.level_m.level_m_1))'
                end

                it 'fails to find all values and throws formatting error' do
                  expect do
                    client.interpolate(raw_hash)
                  end.to(raise_error { |error|
                    expect(error).to be_a(Bosh::Director::ConfigServerFetchError)
                    expect(error.message).to include("- Failed to fetch variable '/hash_placeholder' from config server: Expected parent '/hash_placeholder.ca' hash to have key 'level_n'")
                    expect(error.message).to include("- Failed to fetch variable '/hash_placeholder' from config server: Expected parent '/hash_placeholder.ca' hash to have key 'level_m'")
                  })
                end
              end

              context 'when placeholders use bad dot syntax' do
                before do
                  raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.ca...level_1))'
                end

                it 'fails to find value and throws formatting error' do
                  expect do
                    client.interpolate(raw_hash)
                  end.to(raise_error { |error|
                    expect(error).to be_a(Bosh::Director::ConfigServerIncorrectNameSyntax)
                    expect(error.message).to include("Variable name 'hash_placeholder.ca...level_1' syntax error: Must not contain consecutive dots")
                  })
                end
              end

              it 'returns an error for non absolute path placeholders' do
                raw_hash['properties']['some-new-relative-key'] = '((some-relative-var))'
                expect do
                  client.interpolate(raw_hash)
                end.to(raise_error { |error|
                  expect(error.message).to eq("Relative paths are not allowed in this context. The following must be be switched to use absolute paths: 'some-relative-var'")
                })
              end
            end
          end

          context 'when some placeholders have invalid name syntax' do
            let(:provided_hash) do
              {
                'properties' => {
                  'integer_allowed' => '((int&&&&eger_placeholder))',
                  'nil_allowed' => '((nil_place holder))',
                  'empty_allowed' => '((emp**ty_placeholder))',
                },
                'i_am_a_hash' => {
                  'i_am_an_array' => [
                    {
                      'name' => 'test_job',
                      'properties' => { 'job_prop' => '((job_placeholder+++ ))' },
                    },
                  ],
                },
              }
            end

            # TODO: make sure all the errors are displayed
            it 'should raise an error' do
              expect do
                client.interpolate(provided_hash)
              end.to raise_error Bosh::Director::ConfigServerIncorrectNameSyntax,
                                 "Variable name 'int&&&&eger_placeholder' must only contain alphanumeric, underscores, dashes, or forward slash characters"
            end
          end
        end

        context 'when object to be interpolated is NOT a hash' do
          it 'raises an error' do
            expect do
              client.interpolate('i am not a hash')
            end.to raise_error "Unable to interpolate provided object. Expected a 'Hash', got 'String'"
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
      let(:variable_set_model) { instance_double(Bosh::Director::Models::VariableSet) }
      let(:raw_hash) do
        {
          'properties' => {
            'integer_allowed' => '((integer_placeholder))',
            'nil_allowed' => '((nil_placeholder))',
            'empty_allowed' => '((empty_placeholder))',
          },
          'i_am_a_hash' => {
            'i_am_an_array' => [
              {
                'name' => 'test_job',
                'properties' => { 'job_prop' => '((string_placeholder))' },
              },
            ],
          },
          'i_am_another_array' => [
            { 'env' => { 'env_prop' => '((hash_placeholder))' } },
          ],
          'my_value_will_be_a_hash' => '((hash_placeholder))',
        }
      end
      let(:interpolated_hash) do
        {
          'properties' => {
            'integer_allowed' => 123,
            'nil_allowed' => nil,
            'empty_allowed' => '',
          },
          'i_am_a_hash' => {
            'i_am_an_array' => [
              {
                'name' => 'test_job',
                'properties' => { 'job_prop' => 'i am a string' },
              },
            ],
          },
          'i_am_another_array' => [
            { 'env' => { 'env_prop' => hash_placeholder_value } },
          ],
          'my_value_will_be_a_hash' => hash_placeholder_value,
        }
      end
      let(:hash_placeholder_value) do
        {
          'ca' => {
            'level_1' => 'level_1_value',
            'level_2' => {
              'level_2_1' => 'level_2_1_value',
            },
          },
          'private_key' => 'abc123',
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
              expect do
                client.interpolate_with_versioning(raw_hash, variable_set_model)
              end.to raise_error("- Failed to fetch variable '/smurf_director_name/my_deployment_name/hash_placeholder' " \
                                 "from config server: Expected parent '/smurf_director_name/my_deployment_name/hash_placeholder.ca' hash to have key 'level_n'")
            end
          end

          context 'when multiple errors occur because parts of dot syntax is not found' do
            before do
              raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.ca.level_n.level_n_1))'
              raw_hash['my_value_will_be_an_other_hash'] = '((hash_placeholder.ca.level_m.level_m_1))'
            end

            it 'fails to find all values and throws formatting error' do
              expect do
                client.interpolate_with_versioning(raw_hash, variable_set_model)
              end.to(raise_error { |error|
                expect(error).to be_a(Bosh::Director::ConfigServerFetchError)
                expect(error.message).to include("- Failed to fetch variable '/smurf_director_name/my_deployment_name/hash_placeholder' from config server: Expected parent '/smurf_director_name/my_deployment_name/hash_placeholder.ca' hash to have key 'level_n'")
                expect(error.message).to include("- Failed to fetch variable '/smurf_director_name/my_deployment_name/hash_placeholder' from config server: Expected parent '/smurf_director_name/my_deployment_name/hash_placeholder.ca' hash to have key 'level_m'")
              })
            end
          end

          context 'when placeholders use bad dot syntax' do
            before do
              raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.ca...level_1))'
            end

            it 'fails to find value and throws formatting error' do
              expect do
                client.interpolate_with_versioning(raw_hash, variable_set_model)
              end.to(raise_error { |error|
                expect(error).to be_a(Bosh::Director::ConfigServerIncorrectNameSyntax)
                expect(error.message).to include("Variable name 'hash_placeholder.ca...level_1' syntax error: Must not contain consecutive dots")
              })
            end
          end

          context 'when absolute path is required' do
            it 'returns an error for non absolute path placeholders' do
              expect do
                client.interpolate_with_versioning(raw_hash, variable_set_model, must_be_absolute_name: true)
              end.to(raise_error { |error|
                expect(error.message).to eq("Relative paths are not allowed in this context. The following must be be switched to use absolute paths: 'integer_placeholder', 'nil_placeholder', 'empty_placeholder', 'string_placeholder', 'hash_placeholder', 'hash_placeholder.private_key'")
              })
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
          context 'when hash does NOT contain any placeholders' do
            let(:raw_hash) do
              {
                'properties' => {
                  'integer_allowed' => '1',
                  'nil_allowed' => nil,
                  'empty_allowed' => '',
                },
                'i_am_a_hash' => {
                  'i_am_an_array' => [
                    {
                      'name' => 'test_job',
                      'properties' => { 'job_prop' => 'string' },
                    },
                  ],
                },
                'i_am_another_array' => [
                  { 'env' => { 'env_prop' => {} } },
                ],
                'my_value_will_be_a_hash' => {},
              }
            end

            it 'does not raise an error' do
              expect do
                client.interpolate_with_versioning(raw_hash, variable_set_model)
              end.to_not raise_error
            end

            it 'returns an equivalent hash' do
              interpolated_hash = client.interpolate_with_versioning(raw_hash, variable_set_model)
              expect(interpolated_hash).to eq(raw_hash)
            end
          end

          context 'when all placeholders syntax is correct' do
            let(:integer_placeholder) do
              { 'data' => [{ 'name' => prepend_namespace('integer_placeholder').to_s, 'value' => 123, 'id' => '1' }] }
            end
            let(:nil_placeholder) do
              { 'data' => [{ 'name' => prepend_namespace('nil_placeholder').to_s, 'value' => nil, 'id' => '2' }] }
            end
            let(:empty_placeholder) do
              { 'data' => [{ 'name' => prepend_namespace('empty_placeholder').to_s, 'value' => '', 'id' => '3' }] }
            end
            let(:string_placeholder) do
              { 'data' => [{ 'name' => prepend_namespace('string_placeholder').to_s, 'value' => 'i am a string', 'id' => '4' }] }
            end
            let(:hash_placeholder) do
              {
                'data' => [
                  {
                    'name' => prepend_namespace('hash_placeholder').to_s,
                    'value' => hash_placeholder_value,
                    'id' => '5',
                  },
                ],
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

              let(:response_body_id) do
                { 'name' => variable_name, 'value' => variable_value, 'id' => variable_id }
              end
              let(:response_body_name) do
                { 'data' => [response_body_id] }
              end
              let(:mock_response) { generate_success_response(response_body_name.to_json) }

              before do
                allow(http_client).to receive(:get).with('/boo').and_return(mock_response)
              end

              it 'should raise an error' do
                expect do
                  client.interpolate_with_versioning({ 'key' => "((#{variable_name}))" }, nil)
                end.to raise_error 'Variable Set cannot be nil.'
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
                  expected_error_msg = <<~EXPECTED.strip
                    - Failed to find variable '/smurf_director_name/my_deployment_name/integer_placeholder' with id '1' from config server: HTTP Code '404', Error: 'Name not found'
                    - Failed to find variable '/smurf_director_name/my_deployment_name/nil_placeholder' with id '2' from config server: HTTP Code '404', Error: 'Name not found'
                    - Failed to find variable '/smurf_director_name/my_deployment_name/empty_placeholder' with id '3' from config server: HTTP Code '404', Error: 'Name not found'
                    - Failed to find variable '/smurf_director_name/my_deployment_name/string_placeholder' with id '4' from config server: HTTP Code '404', Error: 'Name not found'
                    - Failed to find variable '/smurf_director_name/my_deployment_name/hash_placeholder' with id '5' from config server: HTTP Code '404', Error: 'Name not found'
                  EXPECTED

                  expect do
                    client.interpolate_with_versioning(raw_hash, variable_set_model)
                  end.to(raise_error { |e|
                    expect(e.message).to eq(expected_error_msg)
                  })
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
                  expected_error_msg = <<~EXPECTED.strip
                    - Failed to fetch variable '/smurf_director_name/my_deployment_name/integer_placeholder' with id '1' from config server: HTTP Code '403', Error: 'There was a problem'
                    - Failed to fetch variable '/smurf_director_name/my_deployment_name/nil_placeholder' with id '2' from config server: HTTP Code '403', Error: 'There was a problem'
                    - Failed to fetch variable '/smurf_director_name/my_deployment_name/empty_placeholder' with id '3' from config server: HTTP Code '403', Error: 'There was a problem'
                    - Failed to fetch variable '/smurf_director_name/my_deployment_name/string_placeholder' with id '4' from config server: HTTP Code '403', Error: 'There was a problem'
                    - Failed to fetch variable '/smurf_director_name/my_deployment_name/hash_placeholder' with id '5' from config server: HTTP Code '403', Error: 'There was a problem'
                  EXPECTED

                  expect do
                    client.interpolate_with_versioning(raw_hash, variable_set_model)
                  end.to(raise_error { |e|
                    expect(e.message).to eq(expected_error_msg)
                  })
                end
              end

              context 'when options passed contain ignored subtrees' do
                let(:ignored_subtrees) do
                  index_integer = Integer

                  ignored_subtrees = []
                  ignored_subtrees << %w[properties integer_allowed]
                  ignored_subtrees << ['i_am_a_hash', 'i_am_an_array', index_integer, 'properties']
                  ignored_subtrees
                end

                let(:interpolated_hash) do
                  {
                    'properties' => {
                      'integer_allowed' => '((integer_placeholder))',
                      'nil_allowed' => nil,
                      'empty_allowed' => '',
                    },
                    'i_am_a_hash' => {
                      'i_am_an_array' => [
                        {
                          'name' => 'test_job',
                          'properties' => { 'job_prop' => '((string_placeholder))' },
                        },
                      ],
                    },
                    'i_am_another_array' => [
                      { 'env' => { 'env_prop' => hash_placeholder_value } },
                    ],
                    'my_value_will_be_a_hash' => hash_placeholder_value,
                  }
                end

                it 'does NOT replace values in ignored subtrees' do
                  expect(http_client).to_not receive(:get_by_id).with('1')
                  expect(http_client).to_not receive(:get_by_id).with('4')
                  expect(client.interpolate_with_versioning(raw_hash, variable_set_model, subtrees_to_ignore: ignored_subtrees)).to eq(interpolated_hash)
                end
              end

              context 'when some placeholders begin with a !' do
                before do
                  raw_hash['properties'] = {
                    '!integer_allowed' => '((integer_placeholder))',
                    '!nil_allowed' => '((nil_placeholder))',
                    '!empty_allowed' => '((empty_placeholder))',
                  }

                  interpolated_hash['properties'] = {
                    '!integer_allowed' => 123,
                    '!nil_allowed' => nil,
                    '!empty_allowed' => '',
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
                    expect do
                      client.interpolate_with_versioning(raw_hash, variable_set_model)
                    end.to raise_error("- Failed to fetch variable '/smurf_director_name/my_deployment_name/hash_placeholder' " \
                                       "from config server: Expected parent '/smurf_director_name/my_deployment_name/hash_placeholder.ca' hash to have key 'level_n'")
                  end
                end

                context 'when multiple errors occur because parts of dot syntax is not found' do
                  before do
                    raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.ca.level_n.level_n_1))'
                    raw_hash['my_value_will_be_an_other_hash'] = '((hash_placeholder.ca.level_m.level_m_1))'
                  end

                  it 'fails to find all values and throws formatting error' do
                    expect do
                      client.interpolate_with_versioning(raw_hash, variable_set_model)
                    end.to(raise_error { |error|
                      expect(error).to be_a(Bosh::Director::ConfigServerFetchError)
                      expect(error.message).to include("- Failed to fetch variable '/smurf_director_name/my_deployment_name/hash_placeholder' from config server: Expected parent '/smurf_director_name/my_deployment_name/hash_placeholder.ca' hash to have key 'level_n'")
                      expect(error.message).to include("- Failed to fetch variable '/smurf_director_name/my_deployment_name/hash_placeholder' from config server: Expected parent '/smurf_director_name/my_deployment_name/hash_placeholder.ca' hash to have key 'level_m'")
                    })
                  end
                end

                context 'when placeholders use bad dot syntax' do
                  before do
                    raw_hash['my_value_will_be_a_hash'] = '((hash_placeholder.ca...level_1))'
                  end

                  it 'fails to find value and throws formatting error' do
                    expect do
                      client.interpolate_with_versioning(raw_hash, variable_set_model)
                    end.to(raise_error { |error|
                      expect(error).to be_a(Bosh::Director::ConfigServerIncorrectNameSyntax)
                      expect(error.message).to include("Variable name 'hash_placeholder.ca...level_1' syntax error: Must not contain consecutive dots")
                    })
                  end
                end

                context 'when absolute path is required' do
                  it 'returns an error for non absolute path placeholders' do
                    expect do
                      client.interpolate_with_versioning(raw_hash, variable_set_model, must_be_absolute_name: true)
                    end.to(raise_error { |error|
                      expect(error.message).to eq("Relative paths are not allowed in this context. The following must be be switched to use absolute paths: 'integer_placeholder', 'nil_placeholder', 'empty_placeholder', 'string_placeholder', 'hash_placeholder', 'hash_placeholder.private_key'")
                    })
                  end
                end
              end

              context 'when response received from server is not in the expected format' do
                let(:raw_hash) do
                  {
                    'name' => 'deployment_name',
                    'properties' => {
                      'name' => '((/bad))',
                    },
                  }
                end

                [
                  { 'response' => 'Invalid JSON response',
                    'message' => "- Failed to fetch variable '/bad' with id '20' from config server: Invalid JSON response" },

                  { 'response' => '{"id" : "some-id"}',
                    'message' => "- Failed to fetch variable '/bad' from config server: Expected response to have key 'value'" },

                  { 'response' => '{"value" : "some-value-foo"}',
                    'message' => "- Failed to fetch variable '/bad' from config server: Expected response to have key 'id'" },

                  { 'response' => '{}',
                    'message' => "- Failed to fetch variable '/bad' from config server: Expected response to have key 'id'" },

                  { 'response' => '[{"name" : "name1", "id" : "id1", "val" : "x"}, {"name" : "name2", "id" : "id2", "val" : "y"}]',
                    'message' => "- Failed to fetch variable '/bad' from config server: Expected response to be a hash, got 'Array'" },
                ].each do |entry|
                  it 'raises an error' do
                    variable_model = instance_double(Bosh::Director::Models::Variable)
                    allow(variable_model).to receive(:variable_name).and_return('/bad')
                    allow(variable_model).to receive(:variable_id).and_return('20')
                    allow(variable_set_model).to receive(:find_variable_by_name).with('/bad').and_return(variable_model)
                    allow(http_client).to receive(:get_by_id).with('20').and_return(generate_success_response(entry['response']))

                    expect do
                      client.interpolate_with_versioning(raw_hash, variable_set_model)
                    end.to(raise_error { |error|
                      expect(error).to be_a(Bosh::Director::ConfigServerFetchError)
                      expect(error.message).to include(entry['message'])
                    })
                  end
                end
              end

              it_behaves_like :variable_name_dot_syntax
            end

            context 'when all the variables to be fetched are not in the current set' do
              before do
                mock_config_store.each do |name, _value|
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
                    allow(variable_set_model).to receive(:add_variable).with(variable_name: name, variable_id: variable_id)
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
                        .with(variable_name: name, variable_id: variable_id)
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
                  expect do
                    client.interpolate_with_versioning(raw_hash, variable_set_model)
                  end.to(raise_error { |error|
                    expect(error).to be_a(Bosh::Director::ConfigServerInconsistentVariableState)
                    expect(error.message).to include("Expected variable '/smurf_director_name/my_deployment_name/integer_placeholder' to be already versioned in deployment 'my_deployment_name'")
                  })
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
                  'empty_allowed' => '((emp**ty_placeholder))',
                },
                'i_am_a_hash' => {
                  'i_am_an_array' => [
                    {
                      'name' => 'test_job',
                      'properties' => { 'job_prop' => '((job_placeholder+++ ))' },
                    },
                  ],
                },
              }
            end

            # TODO: make sure all the errors are displayed
            it 'should raise an error' do
              expect do
                client.interpolate_with_versioning(provided_hash, variable_set_model)
              end.to raise_error Bosh::Director::ConfigServerIncorrectNameSyntax,
                                 "Variable name 'int&&&&eger_placeholder' must only contain alphanumeric, underscores, dashes, or forward slash characters"
            end
          end
        end

        context 'when object to be interpolated is NOT a hash' do
          it 'raises an error' do
            expect do
              client.interpolate_with_versioning('i am not a hash', variable_set_model)
            end.to raise_error "Unable to interpolate provided object. Expected a 'Hash', got 'String'"
          end
        end
      end

      context 'when object to be interpolated is nil' do
        it 'should return nil' do
          expect(client.interpolate_with_versioning(nil, variable_set_model)).to be_nil
        end
      end
    end

    describe '#interpolate_cross_deployment_link' do
      def prepend_provider_namespace(name)
        "/#{director_name}/#{provider_deployment_name}/#{name}"
      end

      let(:integer_placeholder) do
        { 'data' => [{ 'name' => prepend_provider_namespace('integer_placeholder').to_s, 'value' => 123, 'id' => '1' }] }
      end
      let(:cert_placeholder) do
        {
          'data' => [{
            'name' => prepend_provider_namespace('cert_placeholder').to_s,
            'value' => { 'ca' => 'ca_value', 'private_key' => 'abc123' },
            'id' => '2',
          }],
        }
      end
      let(:nil_placeholder) do
        {
          'data' => [{
            'name' => prepend_provider_namespace('nil_placeholder').to_s,
            'value' => nil,
            'id' => '3',
          }],
        }
      end
      let(:empty_placeholder) do
        { 'data' => [{ 'name' => prepend_provider_namespace('empty_placeholder').to_s, 'value' => '', 'id' => '4' }] }
      end
      let(:string_placeholder) do
        { 'data' => [{ 'name' => prepend_provider_namespace('instance_placeholder').to_s, 'value' => 'test1', 'id' => '5' }] }
      end
      let(:absolute_placeholder) do
        { 'data' => [{ 'name' => '/absolute_placeholder', 'value' => 'I am absolute', 'id' => '6' }] }
      end
      let(:hash_placeholder) do
        {
          'data' => [{
            'name' => prepend_provider_namespace('cert_placeholder').to_s,
            'value' => { 'cat' => 'meow', 'dog' => 'woof' },
            'id' => '7',
          }],
        }
      end

      let(:mock_config_store) do
        {
          prepend_provider_namespace('integer_placeholder') => generate_success_response(integer_placeholder.to_json),
          prepend_provider_namespace('cert_placeholder') => generate_success_response(cert_placeholder.to_json),
          prepend_provider_namespace('nil_placeholder') => generate_success_response(nil_placeholder.to_json),
          prepend_provider_namespace('empty_placeholder') => generate_success_response(empty_placeholder.to_json),
          prepend_provider_namespace('string_placeholder') => generate_success_response(string_placeholder.to_json),
          '/absolute_placeholder' => generate_success_response(absolute_placeholder.to_json),
          prepend_provider_namespace('hash_placeholder') => generate_success_response(hash_placeholder.to_json),
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
            'level_1' => '((!string_placeholder))',
          },
          'absolute_allowed' => '((/absolute_placeholder))',
        }
      end

      let(:interpolated_links_properties_spec) do
        {
          'age' => 123,
          'hash_value' => { 'ca' => 'ca_value', 'private_key' => 'abc123' },
          'dots_allowed' => 'meow',
          'nil_allowed' => nil,
          'empty_allowed' => '',
          'nested_allowed' => {
            'level_1' => 'test1',
          },
          'absolute_allowed' => 'I am absolute',
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

      context 'when links spec passed is NOT a hash' do
        it 'throws an error' do
          expect do
            client.interpolate_cross_deployment_link('vroooom', consumer_variable_set, provider_variable_set)
          end.to raise_error "Unable to interpolate cross deployment link properties. Expected a 'Hash', got 'String'"
        end
      end

      context 'when links spec passed is a hash' do
        context 'when links spec hash does NOT contain any placeholders' do
          let(:links_properties_spec) do
            {
              'age' => 6,
              'hash_value' => '0123456789',
              'dots_allowed' => true,
              'nil_allowed' => true,
              'empty_allowed' => true,
              'nested_allowed' => {
                'level_1' => '',
              },
              'absolute_allowed' => 'why?',
            }
          end

          it 'does not raise an error' do
            expect do
              client.interpolate_cross_deployment_link(links_properties_spec, consumer_variable_set, provider_variable_set)
            end.to_not raise_error
          end

          it 'returns a hash equivalent to the links spec hash' do
            interpolated_spec = client.interpolate_cross_deployment_link(links_properties_spec, consumer_variable_set, provider_variable_set)
            expect(interpolated_spec).to eq(links_properties_spec)
          end
        end

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
              expected_error_msg = <<~EXPECTED.strip
                - Failed to find variable '/smurf_director_name/provider_deployment_name/integer_placeholder' with id '1' from config server: HTTP Code '404', Error: 'Name not found'
                - Failed to find variable '/smurf_director_name/provider_deployment_name/cert_placeholder' with id '2' from config server: HTTP Code '404', Error: 'Name not found'
                - Failed to find variable '/smurf_director_name/provider_deployment_name/hash_placeholder' with id '7' from config server: HTTP Code '404', Error: 'Name not found'
                - Failed to find variable '/smurf_director_name/provider_deployment_name/nil_placeholder' with id '3' from config server: HTTP Code '404', Error: 'Name not found'
                - Failed to find variable '/smurf_director_name/provider_deployment_name/empty_placeholder' with id '4' from config server: HTTP Code '404', Error: 'Name not found'
                - Failed to find variable '/smurf_director_name/provider_deployment_name/string_placeholder' with id '5' from config server: HTTP Code '404', Error: 'Name not found'
                - Failed to find variable '/absolute_placeholder' with id '6' from config server: HTTP Code '404', Error: 'Name not found'
              EXPECTED

              expect do
                client.interpolate_cross_deployment_link(links_properties_spec, consumer_variable_set, provider_variable_set)
              end.to(raise_error { |e|
                expect(e.message).to eq(expected_error_msg)
              })
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
              expected_error_msg = <<~EXPECTED.strip
                - Expected variable '/smurf_director_name/provider_deployment_name/integer_placeholder' to be already versioned in deployment 'consumer_deployment_name'
                - Expected variable '/smurf_director_name/provider_deployment_name/cert_placeholder' to be already versioned in deployment 'consumer_deployment_name'
                - Expected variable '/smurf_director_name/provider_deployment_name/hash_placeholder' to be already versioned in deployment 'consumer_deployment_name'
                - Expected variable '/smurf_director_name/provider_deployment_name/nil_placeholder' to be already versioned in deployment 'consumer_deployment_name'
                - Expected variable '/smurf_director_name/provider_deployment_name/empty_placeholder' to be already versioned in deployment 'consumer_deployment_name'
                - Expected variable '/smurf_director_name/provider_deployment_name/string_placeholder' to be already versioned in deployment 'consumer_deployment_name'
                - Expected variable '/absolute_placeholder' to be already versioned in deployment 'consumer_deployment_name'
              EXPECTED

              expect do
                client.interpolate_cross_deployment_link(links_properties_spec, consumer_variable_set, provider_variable_set)
              end.to(raise_error { |e|
                expect(e.message).to eq(expected_error_msg)
              })
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
                  expect(consumer_variable_set).to receive(:add_variable).with(variable_name: name, variable_id: variable_id, is_local: false, provider_deployment: provider_deployment_name)
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
                    .with(
                      variable_name: '/smurf_director_name/provider_deployment_name/string_placeholder',
                      variable_id: '5',
                      is_local: false,
                      provider_deployment: provider_deployment_name,
                    )
                    .and_raise(Sequel::UniqueConstraintViolation.new)
                  allow(consumer_variable_set).to receive(:id).and_return('my_id')
                end

                it 'should catch the exception, log a debug message, and interpolates as correctly' do
                  expect(logger).to receive(:debug).with("Variable '/smurf_director_name/provider_deployment_name/string_placeholder' was already added to consumer variable set 'my_id'")
                  expect do
                    actual_interpolated_link_spec = client.interpolate_cross_deployment_link(links_properties_spec, consumer_variable_set, provider_variable_set)
                    expect(actual_interpolated_link_spec).to eq(interpolated_links_properties_spec)
                  end.to_not raise_error
                end
              end
            end

            context 'when the provider variable set does NOT have the variable' do
              before do
                mock_config_store.each do |name, _value|
                  allow(consumer_variable_set).to receive(:find_provided_variable_by_name).with(name, provider_deployment_name).and_return(nil)
                  allow(provider_variable_set).to receive(:find_variable_by_name).with(name).and_return(nil)
                end
              end

              it 'should raise an exception' do
                expected_error_msg = <<~EXPECTED.strip
                  - Expected variable '/smurf_director_name/provider_deployment_name/integer_placeholder' to be already versioned in link provider deployment 'provider_deployment_name'
                  - Expected variable '/smurf_director_name/provider_deployment_name/cert_placeholder' to be already versioned in link provider deployment 'provider_deployment_name'
                  - Expected variable '/smurf_director_name/provider_deployment_name/hash_placeholder' to be already versioned in link provider deployment 'provider_deployment_name'
                  - Expected variable '/smurf_director_name/provider_deployment_name/nil_placeholder' to be already versioned in link provider deployment 'provider_deployment_name'
                  - Expected variable '/smurf_director_name/provider_deployment_name/empty_placeholder' to be already versioned in link provider deployment 'provider_deployment_name'
                  - Expected variable '/smurf_director_name/provider_deployment_name/string_placeholder' to be already versioned in link provider deployment 'provider_deployment_name'
                  - Expected variable '/absolute_placeholder' to be already versioned in link provider deployment 'provider_deployment_name'
                EXPECTED

                expect do
                  client.interpolate_cross_deployment_link(links_properties_spec,
                                                           consumer_variable_set,
                                                           provider_variable_set)
                end.to(raise_error { |e| expect(e.message).to eq(expected_error_msg) })
              end
            end
          end
        end
      end
    end

    describe '#generate_values' do
      let(:converge_variables) { false }
      let(:use_link_dns_names) { false }
      let(:stemcell_change) { false }

      context 'when given a variables object' do
        context 'when some variable names syntax are NOT correct' do
          let(:variable_specs_list) do
            [
              [{ 'name' => 'p*laceholder_a', 'type' => 'password' }],
              [{ 'name' => 'placeholder_a/', 'type' => 'password' }],
              [{ 'name' => '', 'type' => 'password' }],
              [{ 'name' => ' ', 'type' => 'password' }],
              [{ 'name' => '((vroom))', 'type' => 'password' }],
            ]
          end

          it 'should throw an error and log it' do
            variable_specs_list.each do |variables_spec|
              expect do
                client.generate_values(Bosh::Director::DeploymentPlan::Variables.new(variables_spec), deployment_name)
              end.to raise_error Bosh::Director::ConfigServerIncorrectNameSyntax
            end
          end
        end

        context 'when ALL variable names syntax are correct' do
          let(:variables_spec) do
            [
              { 'name' => 'placeholder_a', 'type' => 'password' },
              { 'name' => 'placeholder_b', 'type' => 'certificate', 'options' => { 'common_name' => 'bosh.io', 'alternative_names' => ['a.bosh.io', 'b.bosh.io'] } },
              { 'name' => '/placeholder_c', 'type' => 'gold', 'options' => { 'need' => 'luck' } },
              { 'name' => 'cred-with-update-mode', 'type' => 'aqua', 'update_mode' => 'overwrite' },
            ]
          end

          let(:variables_obj) do
            Bosh::Director::DeploymentPlan::Variables.new(variables_spec)
          end

          it 'should generate all the variables in order' do
            expect(http_client).to receive(:post).with(
              { 'name' => prepend_namespace('placeholder_a'),
                'type' => 'password',
                'parameters' => {},
                'mode' => 'no-overwrite', }
            ).ordered.and_return(
              generate_success_response(
                {
                  id: 'some_id1',
                }.to_json,
              ),
            )

            expect(http_client).to receive(:post).with(
              { 'name' => prepend_namespace('placeholder_b'),
                'type' => 'certificate',
                'parameters' => { 'common_name' => 'bosh.io', 'alternative_names' => %w[a.bosh.io b.bosh.io] },
                'mode' => 'no-overwrite', }
            ).ordered.and_return(
              generate_success_response(
                {
                  id: 'some_id2',
                }.to_json,
              ),
            )

            expect(http_client).to receive(:post).with(
              { 'name' => '/placeholder_c',
                'type' => 'gold',
                'parameters' => { 'need' => 'luck' },
                'mode' => 'no-overwrite', }
            ).ordered.and_return(
              generate_success_response(
                {
                  id: 'some_id3',
                }.to_json,
              ),
            )

            expect(http_client).to receive(:post).with(
              { 'name' => prepend_namespace('cred-with-update-mode'),
                'type' => 'aqua',
                'parameters' => {},
                'mode' => 'overwrite', }
            ).ordered.and_return(
              generate_success_response(
                {
                  id: 'some_id4',
                }.to_json,
              ),
            )

            client.generate_values(variables_obj, deployment_name)
          end

          it 'should save generated variables to variable table with correct associations' do
            allow(http_client).to receive(:post).and_return(
              generate_success_response({ id: 'some_id1' }.to_json),
              generate_success_response({ id: 'some_id2' }.to_json),
              generate_success_response({ id: 'some_id3' }.to_json),
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
            success_response_1.body = {
              'id' => 1,
              'name' => '/smurf_director_name/deployment_name/placeholder_a',
              'value' => 'abc',
            }.to_json

            success_response_2 = SampleSuccessResponse.new
            success_response_2.body = {
              'id' => 2,
              'name' => '/smurf_director_name/deployment_name/placeholder_b',
              'value' => 'my_cert_value',
            }.to_json

            success_response_3 = SampleSuccessResponse.new
            success_response_3.body = {
              'id' => 3,
              'name' => '/placeholder_c',
              'value' => 'value_3',
            }.to_json

            success_response_4 = SampleSuccessResponse.new
            success_response_4.body = {
              'id' => 4,
              'name' => '/smurf_director_name/deployment_name/cred-with-update-mode',
              'value' => 'value_4',
            }.to_json

            expect(http_client).to receive(:post).with(
              { 'name' => prepend_namespace('placeholder_a'),
                'type' => 'password',
                'parameters' => {},
                'mode' => 'no-overwrite', }
            ).ordered.and_return(success_response_1)

            expect(http_client).to receive(:post).with(
              { 'name' => prepend_namespace('placeholder_b'),
                'type' => 'certificate',
                'parameters' => { 'common_name' => 'bosh.io', 'alternative_names' => %w[a.bosh.io b.bosh.io] },
                'mode' => 'no-overwrite', }
            ).ordered.and_return(success_response_2)

            expect(http_client).to receive(:post).with(
              { 'name' => '/placeholder_c',
                'type' => 'gold',
                'parameters' => { 'need' => 'luck' },
                'mode' => 'no-overwrite', }
            ).ordered.and_return(success_response_3)

            expect(http_client).to receive(:post).with(
              { 'name' => prepend_namespace('cred-with-update-mode'),
                'type' => 'aqua',
                'parameters' => {},
                'mode' => 'overwrite', }
            ).ordered.and_return(success_response_4)

            expect do
              client.generate_values(variables_obj, deployment_name)
            end.to change { Bosh::Director::Models::Event.count }.from(0).to(4)

            event1 = Bosh::Director::Models::Event.order(:id).first
            expect(event1.user).to eq('user')
            expect(event1.action).to eq('create')
            expect(event1.object_type).to eq('variable')
            expect(event1.object_name).to eq('/smurf_director_name/deployment_name/placeholder_a')
            expect(event1.task).to eq(task_id.to_s)
            expect(event1.deployment).to eq(deployment_name)
            expect(event1.instance).to eq(nil)
            expect(event1.context).to eq('update_strategy' => 'on-deploy', 'latest_version' => true, 'id' => 1, 'name' => '/smurf_director_name/deployment_name/placeholder_a')

            event2 = Bosh::Director::Models::Event.order(:id).all[1]
            expect(event2.user).to eq('user')
            expect(event2.action).to eq('create')
            expect(event2.object_type).to eq('variable')
            expect(event2.object_name).to eq('/smurf_director_name/deployment_name/placeholder_b')
            expect(event2.task).to eq(task_id.to_s)
            expect(event2.deployment).to eq(deployment_name)
            expect(event2.instance).to eq(nil)
            expect(event2.context).to eq('update_strategy' => 'on-deploy', 'latest_version' => true, 'id' => 2, 'name' => '/smurf_director_name/deployment_name/placeholder_b')

            event3 = Bosh::Director::Models::Event.order(:id).all[2]
            expect(event3.user).to eq('user')
            expect(event3.action).to eq('create')
            expect(event3.object_type).to eq('variable')
            expect(event3.object_name).to eq('/placeholder_c')
            expect(event3.task).to eq(task_id.to_s)
            expect(event3.deployment).to eq(deployment_name)
            expect(event3.instance).to eq(nil)
            expect(event3.context).to eq('update_strategy' => 'on-deploy', 'latest_version' => true, 'id' => 3, 'name' => '/placeholder_c')

            event4 = Bosh::Director::Models::Event.order(:id).all[3]
            expect(event4.user).to eq('user')
            expect(event4.action).to eq('create')
            expect(event4.object_type).to eq('variable')
            expect(event4.object_name).to eq('/smurf_director_name/deployment_name/cred-with-update-mode')
            expect(event4.task).to eq(task_id.to_s)
            expect(event4.deployment).to eq(deployment_name)
            expect(event4.instance).to eq(nil)
            expect(event4.context).to eq('update_strategy' => 'on-deploy', 'latest_version' => true, 'id' => 4, 'name' => '/smurf_director_name/deployment_name/cred-with-update-mode')
          end

          context 'when variable options contains a CA key' do
            context 'when variable type is certificate' do
              context 'and it consumes `alternative_names` link' do
                let(:variables_spec) do
                  [
                    {
                      'name' => 'placeholder_b',
                      'type' => 'certificate',
                      'consumes' => {
                        'alternative_name' => { 'from' => 'foo' },
                      },
                      'options' => {
                        'ca' => 'my_ca',
                        'common_name' => 'bosh.io',
                        'alternative_names' => ['a.bosh.io', 'b.bosh.io'],
                      },
                    },
                  ]
                end

                let(:link_serial_id) { 8080 }
                let(:deployment_model) do
                  FactoryBot.create(:models_deployment, name: deployment_name, links_serial_id: link_serial_id)
                end

                let(:consumer) do
                  Bosh::Director::Models::Links::LinkConsumer.create(
                    deployment: deployment_model,
                    instance_group: '',
                    type: 'variable',
                    name: 'placeholder_b',
                    serial_id: link_serial_id,
                  )
                end

                let(:consumer_intent) do
                  Bosh::Director::Models::Links::LinkConsumerIntent.create(
                    link_consumer: consumer,
                    original_name: 'alternative_name',
                    type: 'address',
                    name: 'foo',
                    optional: false,
                    blocked: false,
                    serial_id: link_serial_id,
                  )
                end

                let(:consumer_intent2) do
                  Bosh::Director::Models::Links::LinkConsumerIntent.create(
                    link_consumer: consumer,
                    original_name: 'common_name',
                    type: 'address',
                    name: 'foo',
                    optional: false,
                    blocked: false,
                    serial_id: link_serial_id,
                  )
                end

                before do
                  Bosh::Director::Models::Links::Link.create(
                    name: 'foo',
                    link_provider_intent_id: nil,
                    link_consumer_intent_id: consumer_intent.id,
                    link_content: {
                      deployment_name: deployment_name,
                      use_short_dns_addresses: false,
                      instance_group: 'ig1',
                      default_network: 'net-a',
                      domain: 'bosh',
                    }.to_json,
                    created_at: Time.now,
                  )
                end

                it 'should generate the certificate with the SAN appended' do
                  expect(http_client).to receive(:post).with(
                    { 'name' => prepend_namespace('placeholder_b'),
                      'type' => 'certificate',
                      'parameters' => {
                        'ca' => prepend_namespace('my_ca'),
                        'common_name' => 'bosh.io',
                        'alternative_names' => %w[a.bosh.io b.bosh.io q-s0.ig1.net-a.deployment-name.bosh],
                      },
                      'mode' => 'no-overwrite', }
                  ).ordered.and_return(
                    generate_success_response(
                      {
                        id: 'some_id2',
                      }.to_json,
                    ),
                  )

                  client.generate_values(variables_obj, deployment_name)
                end

                context 'when wildcard flag is specified in properties' do
                  let(:variables_spec) do
                    [
                      {
                        'name' => 'placeholder_b',
                        'type' => 'certificate',
                        'consumes' => {
                          'alternative_name' => { 'from' => 'foo', 'properties' => { 'wildcard' => true } },
                        },
                        'options' => {
                          'ca' => 'my_ca',
                          'common_name' => 'bosh.io',
                          'alternative_names' => ['a.bosh.io', 'b.bosh.io'],
                        },
                      },
                    ]
                  end

                  it 'should generate the certificate with the SAN appended' do
                    consumer_intent.metadata = '{"wildcard": true}'
                    consumer_intent.save

                    expect(http_client).to receive(:post).with(
                      { 'name' => prepend_namespace('placeholder_b'),
                        'type' => 'certificate',
                        'parameters' => {
                          'ca' => prepend_namespace('my_ca'),
                          'common_name' => 'bosh.io',
                          'alternative_names' => %w[a.bosh.io b.bosh.io *.ig1.net-a.deployment-name.bosh],
                        },
                        'mode' => 'no-overwrite', }
                    ).ordered.and_return(
                      generate_success_response(
                        {
                          id: 'some_id2',
                        }.to_json,
                      ),
                    )

                    client.generate_values(variables_obj, deployment_name)
                  end
                end

                context 'when common name and SAN is specified' do
                  let(:variables_spec) do
                    [
                      {
                        'name' => 'placeholder_b',
                        'type' => 'certificate',
                        'consumes' => {
                          'alternative_name' => { 'from' => 'foo', 'properties' => { 'wildcard' => true } },
                          'common_name' => { 'from' => 'foo' },
                        },
                        'options' => {
                          'ca' => 'my_ca',
                        },
                      },
                    ]
                  end

                  before do
                    Bosh::Director::Models::Links::Link.create(
                      name: 'foo',
                      link_provider_intent_id: nil,
                      link_consumer_intent_id: consumer_intent2.id,
                      link_content: {
                        deployment_name: deployment_name,
                        use_short_dns_addresses: false,
                        instance_group: 'ig1',
                        default_network: 'net-a',
                        domain: 'bosh',
                      }.to_json,
                      created_at: Time.now,
                    )
                  end

                  it 'should generate the certificate with the common name and SAN' do
                    consumer_intent.metadata = '{"wildcard": true}'
                    consumer_intent.save

                    expect(http_client).to receive(:post).with(
                      { 'name' => prepend_namespace('placeholder_b'),
                        'type' => 'certificate',
                        'parameters' => {
                          'ca' => prepend_namespace('my_ca'),
                          'common_name' => 'q-s0.ig1.net-a.deployment-name.bosh',
                          'alternative_names' => %w[*.ig1.net-a.deployment-name.bosh],
                        },
                        'mode' => 'no-overwrite', }
                    ).ordered.and_return(
                      generate_success_response(
                        {
                          id: 'some_id2',
                        }.to_json,
                      ),
                    )
                    client.generate_values(variables_obj, deployment_name)
                  end

                  context 'when wildcard flag is specified in properties' do
                    let(:variables_spec) do
                      [
                        {
                          'name' => 'placeholder_b',
                          'type' => 'certificate',
                          'consumes' => {
                            'common_name' => { 'from' => 'foo', 'properties' => { 'wildcard' => true } },
                            'alternative_name' => { 'from' => 'foo' },
                          },
                          'options' => {
                            'ca' => 'my_ca',
                            'alternative_names' => ['a.bosh.io', 'b.bosh.io'],
                          },
                        },
                      ]
                    end

                    it 'should generate the certificate with the SAN appended' do
                      consumer_intent2.metadata = '{"wildcard": true}'
                      consumer_intent2.save

                      expect(http_client).to receive(:post).with(
                        { 'name' => prepend_namespace('placeholder_b'),
                          'type' => 'certificate',
                          'parameters' => {
                            'ca' => prepend_namespace('my_ca'),
                            'common_name' => '*.ig1.net-a.deployment-name.bosh',
                            'alternative_names' => %w[a.bosh.io b.bosh.io q-s0.ig1.net-a.deployment-name.bosh],
                          },
                          'mode' => 'no-overwrite', }
                      ).ordered.and_return(
                        generate_success_response(
                          {
                            id: 'some_id2',
                          }.to_json,
                        ),
                      )

                      client.generate_values(variables_obj, deployment_name)
                    end
                  end

                  context 'when common name is also specified in options' do
                    let(:variables_spec) do
                      [
                        {
                          'name' => 'placeholder_b',
                          'type' => 'certificate',
                          'consumes' => {
                            'alternative_name' => { 'from' => 'foo', 'properties' => { 'wildcard' => true } },
                            'common_name' => { 'from' => 'foo' },
                          },
                          'options' => {
                            'ca' => 'my_ca',
                            'common_name' => 'bosh.io',
                          },
                        },
                      ]
                    end

                    before do
                      Bosh::Director::Models::Links::Link.create(
                        name: 'foo',
                        link_provider_intent_id: nil,
                        link_consumer_intent_id: consumer_intent2.id,
                        link_content: {
                          deployment_name: deployment_name,
                          use_short_dns_addresses: false,
                          instance_group: 'ig1',
                          default_network: 'net-a',
                          domain: 'bosh',
                        }.to_json,
                        created_at: Time.now,
                      )
                    end

                    it 'should generate the certificate with options version of the common name' do
                      consumer_intent.metadata = '{"wildcard": true}'
                      consumer_intent.save

                      expect(http_client).to receive(:post).with(
                        { 'name' => prepend_namespace('placeholder_b'),
                          'type' => 'certificate',
                          'parameters' => {
                            'ca' => prepend_namespace('my_ca'),
                            'common_name' => 'bosh.io',
                            'alternative_names' => %w[*.ig1.net-a.deployment-name.bosh],
                          },
                          'mode' => 'no-overwrite', }
                      ).ordered.and_return(
                        generate_success_response(
                          {
                            id: 'some_id2',
                          }.to_json,
                        ),
                      )

                      client.generate_values(variables_obj, deployment_name)
                    end
                  end
                end
              end
            end

            context 'when variable type is certificate & ca is relative' do
              let(:variables_spec) do
                [
                  { 'name' => 'placeholder_b', 'type' => 'certificate', 'options' => { 'ca' => 'my_ca', 'common_name' => 'bosh.io', 'alternative_names' => ['a.bosh.io', 'b.bosh.io'] } },
                ]
              end

              let(:variables_obj) do
                Bosh::Director::DeploymentPlan::Variables.new(variables_spec)
              end

              it 'namespaces the ca reference for a variable with type certificate' do
                expect(http_client).to receive(:post).with(
                  { 'name' => prepend_namespace('placeholder_b'),
                    'type' => 'certificate',
                    'parameters' => {
                      'ca' => prepend_namespace('my_ca'),
                      'common_name' => 'bosh.io',
                      'alternative_names' => %w[a.bosh.io b.bosh.io],
                    },
                    'mode' => 'no-overwrite', }
                ).ordered.and_return(
                  generate_success_response(
                    {
                      id: 'some_id2',
                    }.to_json,
                  ),
                )

                client.generate_values(variables_obj, deployment_name)
              end
            end

            context 'when variable type is certificate & ca is absolute' do
              let(:variables_spec) do
                [
                  {
                    'name' => 'placeholder_b',
                    'type' => 'certificate',
                    'options' => {
                      'ca' => '/my_ca',
                      'common_name' => 'bosh.io',
                      'alternative_names' => ['a.bosh.io', 'b.bosh.io'],
                    },
                  },
                ]
              end

              let(:variables_obj) do
                Bosh::Director::DeploymentPlan::Variables.new(variables_spec)
              end

              it 'namespaces the ca reference for a variable with type certificate' do
                expect(http_client).to receive(:post).with(
                  { 'name' => prepend_namespace('placeholder_b'),
                    'type' => 'certificate',
                    'parameters' => {
                      'ca' => '/my_ca',
                      'common_name' => 'bosh.io',
                      'alternative_names' => %w[a.bosh.io b.bosh.io],
                    },
                    'mode' => 'no-overwrite', }
                ).ordered.and_return(generate_success_response({ id: 'some_id2' }.to_json))

                client.generate_values(variables_obj, deployment_name)
              end
            end

            context 'when variable type is NOT certificate' do
              let(:variables_spec) do
                [
                  { 'name' => 'placeholder_a', 'type' => 'something-else', 'options' => { 'ca' => 'some_ca_value' } },
                ]
              end

              let(:variables_obj) do
                Bosh::Director::DeploymentPlan::Variables.new(variables_spec)
              end

              it 'it passes options through to config server without modification' do
                expect(http_client).to receive(:post).with(
                  { 'name' => prepend_namespace('placeholder_a'),
                    'type' => 'something-else',
                    'parameters' => { 'ca' => 'some_ca_value' },
                    'mode' => 'no-overwrite', }
                ).ordered.and_return(
                  generate_success_response(
                    {
                      id: 'some_id1',
                    }.to_json,
                  ),
                )

                client.generate_values(variables_obj, deployment_name)
              end
            end
          end

          context 'when config server throws an error while generating' do
            before do
              allow(http_client).to receive(:post).with(
                { 'name' => prepend_namespace('placeholder_a'),
                  'type' => 'password',
                  'parameters' => {},
                  'mode' => 'no-overwrite', }
              ).and_return(SampleForbiddenResponse.new)
            end

            it 'should throw an error, log it, and record event' do
              expect(logger).to receive(:error)

              expect do
                client.generate_values(variables_obj, deployment_name)
              end.to raise_error(
                Bosh::Director::ConfigServerGenerationError,
                "Config Server failed to generate value for '/smurf_director_name/deployment_name/placeholder_a' with type 'password'. HTTP Code '403', Error: 'There was a problem'",
              )

              expect(Bosh::Director::Models::Event.count).to eq(1)

              error_event = Bosh::Director::Models::Event.first
              expect(error_event.user).to eq('user')
              expect(error_event.action).to eq('create')
              expect(error_event.object_type).to eq('variable')
              expect(error_event.object_name).to eq('/smurf_director_name/deployment_name/placeholder_a')
              expect(error_event.task).to eq(task_id.to_s)
              expect(error_event.deployment).to eq(deployment_name)
              expect(error_event.instance).to eq(nil)
              expect(error_event.error).to eq("Config Server failed to generate value for '/smurf_director_name/deployment_name/placeholder_a' with type 'password'. HTTP Code '403', Error: 'There was a problem'")
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

              expect do
                client.generate_values(variables_obj, deployment_name)
              end.to raise_error(
                Bosh::Director::ConfigServerGenerationError,
                "Config Server returned a NON-JSON body while generating value for '/smurf_director_name/deployment_name/placeholder_a' with type 'password'. Response body was: 'NOT JSON!!!'",
              )
            end
          end

          context 'but variable set is not writable' do
            let(:deployment_lookup) { instance_double(Bosh::Director::Api::DeploymentLookup) }
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
              expect do
                client.generate_values(variables_obj, deployment_name)
              end.to raise_error(Bosh::Director::ConfigServerGenerationError, "Variable '#{prepend_namespace('placeholder_a')}' cannot be generated. Variable generation allowed only during deploy action")
              expect(models.length).to eq(0)
            end
          end

          context 'when converge_variables is true' do
            let(:converge_variables) { true }
            let(:variables_spec) do
              [
                {
                  'name' => 'placeholder_a',
                  'type' => 'password',
                  'update_mode' => 'overwrite',
                },
                {
                  'name' => 'placeholder_b',
                  'type' => 'certificate',
                  'options' => {
                    'ca' => '/my_ca',
                    'common_name' => 'bosh.io',
                    'alternative_names' => ['a.bosh.io', 'b.bosh.io'],
                  },
                },
              ]
            end

            it 'should set the mode to converge' do
              expect(http_client).to receive(:post).with(
                { 'name' => prepend_namespace('placeholder_a'),
                  'type' => 'password',
                  'parameters' => {},
                  'mode' => 'overwrite', }
              ).ordered.and_return(
                generate_success_response(
                  {
                    id: 'some_id1',
                  }.to_json,
                ),
              )
              expect(http_client).to receive(:post).with(
                { 'name' => prepend_namespace('placeholder_b'),
                  'type' => 'certificate',
                  'parameters' => { 'ca' => '/my_ca', 'common_name' => 'bosh.io', 'alternative_names' => %w[a.bosh.io b.bosh.io] },
                  'mode' => 'converge', }
              ).ordered.and_return(
                generate_success_response(
                  {
                    id: 'some_id2',
                  }.to_json,
                ),
              )
              client.generate_values(variables_obj, deployment_name, converge_variables)
            end
          end

          context 'when use_link_dns_names is set to true' do
            let(:use_link_dns_names) { true }
            let(:variables_spec) do
              [
                {
                  'name' => 'placeholder_b',
                  'type' => 'certificate',
                  'consumes' => {
                    'alternative_name' => { 'from' => 'foo', 'link_type' => 'something', 'properties' => { 'wildcard' => true } },
                  },
                  'options' => {
                    'ca' => 'my_ca',
                    'common_name' => 'bosh.io',
                    'alternative_names' => ['a.bosh.io', 'b.bosh.io'],
                  },
                },
              ]
            end

            let(:link_serial_id) { 8080 }
            let(:deployment_model) do
              FactoryBot.create(:models_deployment, name: deployment_name, links_serial_id: link_serial_id)
            end

            let(:consumer) do
              Bosh::Director::Models::Links::LinkConsumer.create(
                deployment: deployment_model,
                instance_group: '',
                type: 'variable',
                name: 'placeholder_b',
                serial_id: link_serial_id,
              )
            end

            let(:consumer_intent) do
              Bosh::Director::Models::Links::LinkConsumerIntent.create(
                link_consumer: consumer,
                original_name: 'alternative_name',
                type: 'something',
                name: 'foo',
                optional: false,
                blocked: false,
                serial_id: link_serial_id,
                metadata: '{"wildcard": true}',
              )
            end

            let(:consumer_intent2) do
              Bosh::Director::Models::Links::LinkConsumerIntent.create(
                link_consumer: consumer,
                original_name: 'common_name',
                type: 'something',
                name: 'foo',
                optional: false,
                blocked: false,
                serial_id: link_serial_id,
              )
            end

            let(:encoded_group) do
              Bosh::Director::Models::LocalDnsEncodedGroup.create(
                name: 'foo-something',
                type: 'link',
                deployment: deployment_model,
              )
            end

            before do
              FactoryBot.create(:models_local_dns_encoded_network, name: 'net-a')
              Bosh::Director::Models::Links::Link.create(
                name: 'foo',
                link_provider_intent: FactoryBot.create(:models_links_link_provider_intent, name: 'foo', type: 'something'),
                link_consumer_intent_id: consumer_intent.id,
                link_content: {
                  deployment_name: deployment_name,
                  instance_group: 'ig1',
                  default_network: 'net-a',
                  domain: 'bosh',
                }.to_json,
                created_at: Time.now,
              )
            end

            it 'should generate the certificate with the SAN appended' do
              expect(http_client).to receive(:post).with(
                { 'name' => prepend_namespace('placeholder_b'),
                  'type' => 'certificate',
                  'parameters' => {
                    'ca' => prepend_namespace('my_ca'),
                    'common_name' => 'bosh.io',
                    'alternative_names' => %W[a.bosh.io b.bosh.io *.q-g#{encoded_group.id}.bosh],
                  },
                  'mode' => 'no-overwrite', }
              ).ordered.and_return(
                generate_success_response(
                  {
                    id: 'some_id2',
                  }.to_json,
                ),
              )

              client.generate_values(variables_obj, deployment_name, converge_variables, use_link_dns_names)
            end
          end

          context 'stemcell_change' do
            let(:variables_spec) do
              [
                { 'name' => 'placeholder_a', 'type' => 'password' },
                { 'name' => 'placeholder_b', 'type' => 'password', 'update' => { 'strategy' => 'on-stemcell-change' } },
              ]
            end
            let(:previous_variable_set) do
              FactoryBot.create(:models_variable_set,
                deployment: deployment_model,
                deployed_successfully: false,
                writable: false,
                created_at: 2.days.ago,
              )
            end
            let!(:on_stemcell_change_variable) do
              FactoryBot.create(:models_variable,
                variable_id: 'some_id99',
                variable_name: '/smurf_director_name/deployment_name/placeholder_b',
                variable_set: previous_variable_set,
              )
            end

            before do
              expect(http_client).to receive(:post).with(
                { 'name' => prepend_namespace('placeholder_a'),
                  'type' => 'password',
                  'parameters' => {},
                  'mode' => 'no-overwrite', }
              ).ordered.and_return(
                generate_success_response(
                  {
                    id: 'some_id1',
                    name: '/smurf_director_name/deployment_name/placeholder_a',
                    value: 'abc',
                  }.to_json,
                  ),
                )
            end

            context 'stemcell_change is set to false' do
              it 'only affects variables with on-stemcell-change update strategy' do
                expect(http_client).not_to receive(:post).with(
                  { 'name' => prepend_namespace('placeholder_b'),
                    'type' => 'password',
                    'parameters' => {},
                    'mode' => 'no-overwrite', }
                ).ordered

                client.generate_values(variables_obj, deployment_name, converge_variables, use_link_dns_names, stemcell_change)
              end

              it 'references the value from the previous variable set' do
                expect(Bosh::Director::Models::Variable[variable_id: 'some_id99', variable_name: prepend_namespace('placeholder_b'), variable_set_id: variables_set_id]).to be_nil

                client.generate_values(variables_obj, deployment_name, converge_variables, use_link_dns_names, stemcell_change)

                expect(Bosh::Director::Models::Variable[variable_id: 'some_id99', variable_name: prepend_namespace('placeholder_b'), variable_set_id: variables_set_id]).to_not be_nil
              end

              context 'when there is no previous_variable_set' do
                before do
                  previous_variable_set.delete
                end

                it 'creates a new variable' do
                  expect(http_client).to receive(:post).with(
                    { 'name' => prepend_namespace('placeholder_b'),
                      'type' => 'password',
                      'parameters' => {},
                      'mode' => 'no-overwrite', }
                  ).ordered.and_return(
                    generate_success_response(
                      {
                        id: 'some_id2',
                      }.to_json,
                      ),
                    )

                  client.generate_values(variables_obj, deployment_name, converge_variables, use_link_dns_names, stemcell_change)
                end
              end

              context "when the previous version of the variable is not found even though there's been a previous deploy" do
                it 'creates a new variable' do
                  on_stemcell_change_variable.delete
                  expect(http_client).to receive(:post).with(
                    { 'name' => prepend_namespace('placeholder_b'),
                      'type' => 'password',
                      'parameters' => {},
                      'mode' => 'no-overwrite', }
                  ).ordered.and_return(
                    generate_success_response(
                      {
                        id: 'some_id2',
                      }.to_json,
                      ),
                    )
                  client.generate_values(variables_obj, deployment_name, converge_variables, use_link_dns_names, stemcell_change)
                end
              end

              context 'handles unique constraint violation when saving variable' do
                let(:variable_set) { instance_double(Bosh::Director::Models::VariableSet) }

                before do
                  allow_any_instance_of(Bosh::Director::Models::Deployment).to receive(:current_variable_set).and_return(variable_set)
                  allow(variable_set).to receive(:add_variable)
                    .with(
                      variable_name: '/smurf_director_name/deployment_name/placeholder_a',
                      variable_id: 'some_id1',
                    )
                  allow(variable_set).to receive(:add_variable)
                    .with(
                      variable_name: '/smurf_director_name/deployment_name/placeholder_b',
                      variable_id: 'some_id99',
                    )
                    .and_raise(Sequel::UniqueConstraintViolation.new)
                  allow(variable_set).to receive(:id).and_return('my_id')
                  allow(variable_set).to receive(:writable).and_return(true)
                end

                it 'should catch the exception, log a debug message, and interpolates as correctly' do
                  expect(logger).to receive(:debug).with("variable '/smurf_director_name/deployment_name/placeholder_b' was already added to set 'my_id'")
                  expect do
                    client.generate_values(variables_obj, deployment_name, converge_variables, use_link_dns_names, stemcell_change)
                  end.to_not raise_error
                end
              end

              it 'adds an event showing when this strategy is being used' do
                expect do
                  client.generate_values(variables_obj, deployment_name, converge_variables, use_link_dns_names, stemcell_change)
                end.to change { Bosh::Director::Models::Event.count }.from(0).to(2)

                event1 = Bosh::Director::Models::Event.order(:id).first
                expect(event1.user).to eq('user')
                expect(event1.action).to eq('create')
                expect(event1.object_type).to eq('variable')
                expect(event1.object_name).to eq('/smurf_director_name/deployment_name/placeholder_a')
                expect(event1.task).to eq(task_id.to_s)
                expect(event1.deployment).to eq(deployment_name)
                expect(event1.instance).to eq(nil)
                expect(event1.context).to eq('update_strategy' => 'on-deploy', 'latest_version' => true, 'id' => 'some_id1', 'name' => '/smurf_director_name/deployment_name/placeholder_a')

                event2 = Bosh::Director::Models::Event.order(:id).all[1]
                expect(event2.user).to eq('user')
                expect(event2.action).to eq('create')
                expect(event2.object_type).to eq('variable')
                expect(event2.object_name).to eq('/smurf_director_name/deployment_name/placeholder_b')
                expect(event2.task).to eq(task_id.to_s)
                expect(event2.deployment).to eq(deployment_name)
                expect(event2.instance).to eq(nil)
                expect(event2.context).to eq('update_strategy' => 'on-stemcell-change', 'latest_version' => false, 'id' => 'some_id99', 'name' => '/smurf_director_name/deployment_name/placeholder_b')
              end
            end

            context 'stemcell_change is set to true' do
              let(:stemcell_change) { true }

              before do
                expect(http_client).to receive(:post).with(
                  { 'name' => prepend_namespace('placeholder_b'),
                    'type' => 'password',
                    'parameters' => {},
                    'mode' => 'no-overwrite', }
                ).ordered.and_return(
                  generate_success_response(
                    {
                      id: 'some_id2',
                    }.to_json,
                  ),
                )
              end

              it 'generates a new version of the variables with on-stemcell-change update strategy' do
                client.generate_values(variables_obj, deployment_name, converge_variables, use_link_dns_names, stemcell_change)
              end

              it 'adds an event showing when this strategy is being used and that the version is latest' do
                expect do
                  client.generate_values(variables_obj, deployment_name, converge_variables, use_link_dns_names, stemcell_change)
                end.to change { Bosh::Director::Models::Event.count }.from(0).to(2)

                event2 = Bosh::Director::Models::Event.order(:id).all[1]
                expect(event2.user).to eq('user')
                expect(event2.action).to eq('create')
                expect(event2.object_type).to eq('variable')
                expect(event2.object_name).to eq('/smurf_director_name/deployment_name/placeholder_b')
                expect(event2.task).to eq(task_id.to_s)
                expect(event2.deployment).to eq(deployment_name)
                expect(event2.instance).to eq(nil)
                expect(event2.context).to eq('update_strategy' => 'on-stemcell-change', 'latest_version' => true, 'id' => 'some_id2', 'name' => '/smurf_director_name/deployment_name/placeholder_b')
              end
            end
          end
        end
      end
    end

    describe '#interpolated_versioned_variables_changed?' do
      let(:previous_variable_set) do
        FactoryBot.create(:models_variable_set, deployment: deployment_model)
      end

      let(:next_variable_set) do
        FactoryBot.create(:models_variable_set, deployment: deployment_model, writable: true)
      end

      let(:tasty_response) do
        { 'name' => prepend_namespace('taste').to_s, 'value' => 'i am a string', 'id' => '1' }
      end

      let(:tasty_response2) do
        { 'data' => [{ 'name' => prepend_namespace('taste').to_s, 'value' => 'i am a string meow', 'id' => '2' }] }
      end

      let(:settings_hash) do
        { 'cookies' => '((taste))' }
      end

      before do
        previous_variable_set.add_variable(variable_name: '/smurf_director_name/deployment_name/taste',
                                           variable_id: '1',
                                           is_local: true,
                                           provider_deployment: deployment_model.name)
      end

      it 'returns true when the previous and next hashes differ' do
        allow(http_client).to receive(:get_by_id).with('1')
                                                 .and_return(generate_success_response(tasty_response.to_json))

        allow(http_client).to receive(:get).with('/smurf_director_name/deployment_name/taste')
                                           .and_return(generate_success_response(tasty_response2.to_json))

        expect(client.interpolated_versioned_variables_changed?(settings_hash, settings_hash,
                                                                previous_variable_set, next_variable_set)).to be_truthy
      end

      it 'returns false when the previous and next hashes match' do
        allow(http_client).to receive(:get_by_id).with('1')
                                                 .and_return(generate_success_response(tasty_response.to_json))

        tasty_response2['data'][0] = tasty_response
        allow(http_client).to receive(:get).with('/smurf_director_name/deployment_name/taste')
                                           .and_return(generate_success_response(tasty_response2.to_json))

        expect(client.interpolated_versioned_variables_changed?(settings_hash, settings_hash,
                                                                previous_variable_set, next_variable_set)).to be_falsey
      end

      it 'returns true when one or more variables are unable to be obtained' do
        allow(logger).to receive(:debug)
        allow(http_client).to receive(:get_by_id).with('1')
                                                 .and_return(SampleNotFoundResponse.new)

        expect(client.interpolated_versioned_variables_changed?(settings_hash, settings_hash,
                                                                previous_variable_set, next_variable_set)).to be_truthy
      end
    end

    def generate_success_response(body)
      result = SampleSuccessResponse.new
      result.body = body
      result
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
      super(nil, '404', '')
    end

    def body
      '{"error": "Name not found"}'
    end
  end

  class SampleForbiddenResponse < Net::HTTPForbidden
    def initialize
      super(nil, '403', '')
    end

    def body
      '{"error": "There was a problem"}'
    end
  end
end
