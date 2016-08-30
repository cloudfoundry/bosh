require 'spec_helper'

module Bosh::Director::ConfigServer
  describe Client do
    subject(:client) { Client.new(http_client, logger) }
    let(:logger) { double('Logging::Logger') }

    before do
      allow(logger).to receive(:info)
    end

    context '#interpolate' do
      let(:interpolated_manifest) { client.interpolate(manifest_hash, ignored_subtrees) }
      let(:manifest_hash) { {} }
      let(:ignored_subtrees) {[]}
      let(:mock_config_store) do
        {
          'value' => generate_success_response({'value' => 123}.to_json),
          'instance_placeholder' => generate_success_response({'value' => 'test1'}.to_json),
          'job_placeholder' => generate_success_response({'value' => 'test2'}.to_json),
          'env_placeholder' => generate_success_response({'value' => 'test3'}.to_json),
          'name_placeholder' => generate_success_response({'value' => 'test4'}.to_json)
        }
      end
      let(:http_client) { double('Bosh::Director::ConfigServer::HTTPClient') }

      before do
        mock_config_store.each do |key, value|
          allow(http_client).to receive(:get).with(key).and_return(value)
        end
      end

      it 'should return a new copy of the original manifest' do
        expect(client.interpolate(manifest_hash, ignored_subtrees)).to_not equal(manifest_hash)
      end

      it 'should request keys from the proper url' do
        expected_result = { 'properties' => {'key' => 123 } }

        manifest_hash['properties'] = { 'key' => '((value))' }
        expect(interpolated_manifest).to eq(expected_result)
      end

      it 'should replace any top level property key in the passed hash' do
        manifest_hash['name'] = '((name_placeholder))'

        expected_manifest = {
          'name' => 'test4'
        }

        expect(interpolated_manifest).to eq(expected_manifest)
      end

      it 'should replace the global property keys in the passed hash' do
        manifest_hash['properties'] = { 'key' => '((value))' }

        expected_manifest = {
          'properties' => { 'key' => 123 }
        }

        expect(interpolated_manifest).to eq(expected_manifest)
      end

      it 'should replace the instance group property keys in the passed hash' do
        manifest_hash['instance_groups'] = [
          {
            'name' => 'bla',
            'properties' => { 'instance_prop' => '((instance_placeholder))' }
          }
        ]

        expected_manifest = {
          'instance_groups' => [
            {
              'name' => 'bla',
              'properties' => { 'instance_prop' => 'test1' }
            }
          ]
        }

        expect(interpolated_manifest).to eq(expected_manifest)
      end

      it 'should replace the env keys in the passed hash' do
        manifest_hash['resource_pools'] =  [ {'env' => {'env_prop' => '((env_placeholder))'} } ]

        expected_manifest = {
          'resource_pools' => [ {'env' => {'env_prop' => 'test3'} } ]
        }

        expect(interpolated_manifest).to eq(expected_manifest)
      end

      it 'should replace the job properties in the passed hash' do
        manifest_hash['instance_groups'] = [
          {
            'name' => 'bla',
            'jobs' => [
              {
                'name' => 'test_job',
                'properties' => { 'job_prop' => '((job_placeholder))' }
              }
            ]
          }
        ]

        expected_manifest = {
          'instance_groups' => [
            {
              'name' => 'bla',
              'jobs' => [
                {
                  'name' => 'test_job',
                  'properties' => { 'job_prop' => 'test2' }
                }
              ]
            }
          ]
        }

        expect(interpolated_manifest).to eq(expected_manifest)
      end

      it 'should raise a missing key error message when key is not found in the config_server' do
        allow(http_client).to receive(:get).with('missing_placeholder').and_return(SampleNotFoundResponse.new)

        manifest_hash['properties'] = { 'key' => '((missing_placeholder))' }
        expect{
          interpolated_manifest
        }.to raise_error(
               Bosh::Director::ConfigServerMissingKeys,
               'Failed to find keys in the config server: missing_placeholder')
      end

      it 'should raise an unknown error when config_server returns any error other than a 404' do
        allow(http_client).to receive(:get).with('missing_placeholder').and_return(SampleErrorResponse.new)

        manifest_hash['properties'] = { 'key' => '((missing_placeholder))' }
        expect{
          interpolated_manifest
        }.to raise_error(Bosh::Director::ConfigServerUnknownError)
      end

      context 'ignored subtrees' do
        let(:mock_config_store) do
          {
            'release_1_placeholder' => generate_success_response({'value' => 'release_1'}.to_json),
            'release_2_version_placeholder' => generate_success_response({'value' => 'v2'}.to_json),
            'job_name' => generate_success_response({'value' => 'spring_server'}.to_json)
          }
        end

        let(:manifest_hash) do
          {
            'releases' => [
              {'name' => '((release_1_placeholder))', 'version' => 'v1'},
              {'name' => 'release_2', 'version' => '((release_2_version_placeholder))'}
            ],
            'instance_groups' => [
              {
                'name' => 'logs',
                'env' => { 'smurf' => '((smurf_placeholder))' },
                'jobs' => [
                  {
                    'name' => 'mysql',
                    'properties' => {'foo' => '((foo_place_holder))', 'bar' => {'smurf' => '((smurf_placeholder))'}}
                  },
                  {
                    'name' => '((job_name))'
                  }
                ],
                'properties' => {'a' => ['123', 45, '((secret_key))']}
              }
            ],
            'properties' => {
              'global_property' => '((something))'
            },
            'resource_pools' => [
              {
                'name' => 'resource_pool_name',
                'env' => {
                  'f' => '((f_placeholder))'
                }
              }
            ]
          }
        end

        let(:interpolated_manifest_hash) do
          {
            'releases' => [
              {'name' => 'release_1', 'version' => 'v1'},
              {'name' => 'release_2', 'version' => 'v2'}
            ],
            'instance_groups' => [
              {
                'name' => 'logs',
                'env' => {'smurf' => '((smurf_placeholder))'},
                'jobs' => [
                  {
                    'name' => 'mysql',
                    'properties' => {'foo' => '((foo_place_holder))', 'bar' => {'smurf' => '((smurf_placeholder))'}}
                  },
                  {
                    'name' => 'spring_server'
                  }
                ],
                'properties' => {'a' => ['123', 45, '((secret_key))']}
              }
            ],
            'properties' => {
              'global_property' => '((something))'
            },
            'resource_pools' => [
              {
                'name' => 'resource_pool_name',
                'env' => {
                  'f' => '((f_placeholder))'
                }
              }
            ]
          }
        end

        let(:ignored_subtrees) do
          index_type = Integer
          any_string = String

          ignored_subtrees = []
          ignored_subtrees << ['properties']
          ignored_subtrees << ['instance_groups', index_type, 'properties']
          ignored_subtrees << ['instance_groups', index_type, 'jobs', index_type, 'properties']
          ignored_subtrees << ['instance_groups', index_type, 'jobs', index_type, 'consumes', any_string, 'properties']
          ignored_subtrees << ['jobs', index_type, 'properties']
          ignored_subtrees << ['jobs', index_type, 'templates', index_type, 'properties']
          ignored_subtrees << ['jobs', index_type, 'templates', index_type, 'consumes', any_string, 'properties']
          ignored_subtrees << ['instance_groups', index_type, 'env']
          ignored_subtrees << ['jobs', index_type, 'env']
          ignored_subtrees << ['resource_pools', index_type, 'env']
          ignored_subtrees
        end

        it 'should not replace values in ignored subtrees' do
          expect(interpolated_manifest).to eq(interpolated_manifest_hash)
        end
      end
    end

    describe '#interpolate_deployment_manifest' do
      let(:http_client) { double('Bosh::Director::ConfigServer::HTTPClient') }

      let(:ignored_subtrees) do
        index_type = Integer
        any_string = String

        ignored_subtrees = []
        ignored_subtrees << ['properties']
        ignored_subtrees << ['instance_groups', index_type, 'properties']
        ignored_subtrees << ['instance_groups', index_type, 'jobs', index_type, 'properties']
        ignored_subtrees << ['instance_groups', index_type, 'jobs', index_type, 'consumes', any_string, 'properties']
        ignored_subtrees << ['jobs', index_type, 'properties']
        ignored_subtrees << ['jobs', index_type, 'templates', index_type, 'properties']
        ignored_subtrees << ['jobs', index_type, 'templates', index_type, 'consumes', any_string, 'properties']
        ignored_subtrees << ['instance_groups', index_type, 'env']
        ignored_subtrees << ['jobs', index_type, 'env']
        ignored_subtrees << ['resource_pools', index_type, 'env']
        ignored_subtrees
      end

      it 'should call interpolate with the correct arguments' do
        expect(subject).to receive(:interpolate).with({'name' => '{{placeholder}}'}, ignored_subtrees).and_return({'name' => 'smurf'})
        result = subject.interpolate_deployment_manifest({'name' => '{{placeholder}}'})
        expect(result).to eq({'name' => 'smurf'})
      end
    end

    describe '#interpolate_runtime_manifest' do
      let(:http_client) { double('Bosh::Director::ConfigServer::HTTPClient') }

      let(:ignored_subtrees) do
        index_type = Integer
        any_string = String

        ignored_subtrees = []
        ignored_subtrees << ['addons', index_type, 'properties']
        ignored_subtrees << ['addons', index_type, 'jobs', index_type, 'properties']
        ignored_subtrees << ['addons', index_type, 'jobs', index_type, 'consumes', any_string, 'properties']
        ignored_subtrees
      end

      it 'should call interpolate with the correct arguments' do
        expect(subject).to receive(:interpolate).with({'name' => '{{placeholder}}'}, ignored_subtrees).and_return({'name' => 'smurf'})
        result = subject.interpolate_runtime_manifest({'name' => '{{placeholder}}'})
        expect(result).to eq({'name' => 'smurf'})
      end
    end

    describe '#populate_value_for' do
      let(:http_client) { double('Bosh::Director::ConfigServer::HTTPClient') }

      context 'when key is nil' do
        it 'does NOT contact the config server' do
          expect(http_client).to_not receive(:get)
          expect(http_client).to_not receive(:post)
          client.populate_value_for(nil, 'password')
        end
      end

      context 'when the key does not start with (( and ends with ))' do
        it 'does NOT contact the config server regardless of type' do
          expect(http_client).to_not receive(:get)
          expect(http_client).to_not receive(:post)
          client.populate_value_for('key_1', 'password')
          client.populate_value_for('key_2', nil)
          client.populate_value_for('key_3', 'anything')
          client.populate_value_for('((key_4)', 'password')
        end
      end

      context 'password generation' do
        let (:type) { 'password'}
        let (:key) { '((smurf_password))'}
        let(:response_body) { {'value'=> 'very_secret'} }
        let(:mock_response) do
          response = SampleSuccessResponse.new
          response.body = response_body.to_json
          response
        end

        context 'when key already exists in config server' do
          before do
            allow(http_client).to receive(:get).with('smurf_password').and_return(mock_response)
          end
          it 'does NOT make a call to generate_password' do
            expect(http_client).to_not receive(:post)
            client.populate_value_for(key, type)
          end
        end

        context 'when key does NOT exist in config server' do
          before do
            allow(http_client).to receive(:get).with('smurf_password').and_return(SampleNotFoundResponse.new)
          end
          it 'makes a call to generate_password with trimmed key' do
            expect(http_client).to receive(:post).with('smurf_password', {'type' => 'password'}).and_return(SampleSuccessResponse.new)
            client.populate_value_for(key, type)
          end
        end

        context 'when an error is thrown from config server while checking if key exists' do
          before do
            allow(http_client).to receive(:get).with('smurf_password').and_return(SampleErrorResponse.new)
          end
          it 'should raise an error' do
            expect(http_client).to_not receive(:post)
            expect{
              client.populate_value_for(key, type)
            }.to raise_error(Bosh::Director::ConfigServerUnknownError)
          end
        end
      end

      context "when type is not the string 'password'" do
        it 'does NOT contact the config server' do
          expect(http_client).to_not receive(:get)
          expect(http_client).to_not receive(:post)
          client.populate_value_for('my_db_name', 'hello')
          client.populate_value_for('my_db_name', nil)
          client.populate_value_for('my_db_name', '')
        end
      end

      context 'when type is password' do
        let (:type) { 'password'}
        let (:key) { '((smurf_password))'}
        let(:response_body) { {'value'=> 'very_secret'} }
        let(:mock_response) { generate_success_response(response_body.to_json) }

        context 'when config server post response is not successful' do
          before do
            allow(http_client).to receive(:get).with('smurf_password').and_return(SampleNotFoundResponse.new)
            allow(http_client).to receive(:post).with('smurf_password', {'type' => 'password'}).and_return(SampleNotFoundResponse.new)
          end

          it 'raises an error' do
            expect{
              client.populate_value_for(key, type)
            }. to raise_error(
              Bosh::Director::ConfigServerPasswordGenerationError,
              'Config Server failed to generate password'
            )
          end
        end

        context 'when key already exists in config server' do
          before do
            allow(http_client).to receive(:get).with('smurf_password').and_return(mock_response)
          end
          it 'does NOT make a call to generate_password' do
            expect(http_client).to_not receive(:post)
            client.populate_value_for(key, type)
          end
        end

        context 'when key does NOT exist in config server' do
          before do
            allow(http_client).to receive(:get).with('smurf_password').and_return(SampleNotFoundResponse.new)
          end
          it 'makes a call to generate_password with trimmed key' do
            expect(http_client).to receive(:post).with('smurf_password', {'type' => 'password'}).and_return(SampleSuccessResponse.new)
            client.populate_value_for(key, type)
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

  describe DummyClient do

    subject(:dummy_client) { DummyClient.new }

    describe '#interpolate' do
      let(:src) do
        {
          'test' => 'smurf',
          'test2' => '((placeholder))'
        }
      end

      it 'returns src as is' do
        expect(dummy_client.interpolate(src)).to eq(src)
      end
    end

    describe '#interpolate_deployment_manifest' do
      let(:manifest) do
        {
          'test' => 'smurf',
          'test2' => '((placeholder))'
        }
      end

      it 'returns manifest as is' do
        expect(dummy_client.interpolate_deployment_manifest(manifest)).to eq(manifest)
      end
    end

    describe '#interpolate_runtime_manifest' do
      let(:manifest) do
        {
          'test' => 'smurf',
          'test2' => '((placeholder))'
        }
      end

      it 'returns manifest as is' do
        expect(dummy_client.interpolate_runtime_manifest(manifest)).to eq(manifest)
      end
    end

    describe '#populate_value_for' do
      let(:src) do
        {
          'test' => 'smurf',
          'test2' => '((placeholder))'
        }
      end

      it 'is a no op' do
        expect(dummy_client).to respond_to(:populate_value_for).with(2).arguments
      end
    end

  end

  class SampleSuccessResponse < Net::HTTPOK
    attr_accessor :body

    def initialize
      super(nil, Net::HTTPOK, nil)
    end
  end

  class SampleNotFoundResponse < Net::HTTPNotFound
    def initialize
      super(nil, Net::HTTPNotFound, 'Not Found Brah')
    end
  end

  class SampleErrorResponse < Net::HTTPForbidden
    def initialize
      super(nil, Net::HTTPForbidden, 'There was a problem.')
    end
  end
end