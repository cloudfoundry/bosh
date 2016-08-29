require 'spec_helper'

module Bosh::Director::ConfigServer
  describe Interpolator do
    class MockSuccessResponse < Net::HTTPSuccess
      attr_accessor :body

      def initialize
        super(nil, Net::HTTPOK, nil)
      end
    end

    class MockFailedResponse < Net::HTTPClientError
      def initialize
        super(nil, Net::HTTPNotFound, nil)
      end
    end

    def generate_success_response(body)
      result = MockSuccessResponse.new
      result.body = body
      result
    end

    context '#interpolate' do
      subject(:interpolator) { Interpolator.new(http_client, nil) }

      let(:interpolated_manifest) { interpolator.interpolate(manifest_hash, ignored_subtrees) }
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
        expect(interpolator.interpolate(manifest_hash, ignored_subtrees)).to_not equal(manifest_hash)
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

      it 'should raise an error message when key is missing from the config_server' do
        allow(http_client).to receive(:get).with('missing_placeholder').and_return(MockFailedResponse.new)

        manifest_hash['properties'] = { 'key' => '((missing_placeholder))' }
        expect{
          interpolated_manifest
        }.to raise_error(
               Bosh::Director::ConfigServerMissingKeys,
               'Failed to find keys in the config server: missing_placeholder')
      end

      it 'should not replace values in ignored subtrees' do
        index_type = Integer
        ignored_subtrees << ['instance_groups', index_type, 'jobs', index_type, 'properties']

        manifest_hash['instance_groups'] = [
          {
            'name' => '((name_placeholder))',
            'jobs' => [
              {
                'name' => 'test_job',
                'properties' => { 'job_prop' => '((job_placeholder))' },
              }
            ]
          }
        ]

        expected_manifest = {
          'instance_groups' => [
            {
              'name' => 'test4',
              'jobs' => [
                {
                  'name' => 'test_job',
                  'properties' => { 'job_prop' => '((job_placeholder))' },
                }
              ]
            }
          ]
        }

        expect(interpolated_manifest).to eq(expected_manifest)
      end
    end

    describe '#populate_value_for' do
      subject(:interpolator) { Interpolator.new(http_client, nil) }
      let(:http_client) { double('Bosh::Director::ConfigServer::HTTPClient') }

      context 'when key is nil' do
        it 'does NOT contact the config server' do
          expect(http_client).to_not receive(:get)
          expect(http_client).to_not receive(:post)
          interpolator.populate_value_for(nil, 'password')
        end
      end

      context 'when the key does not start with (( and ends with ))' do
        it 'does NOT contact the config server regardless of type' do
          expect(http_client).to_not receive(:get)
          expect(http_client).to_not receive(:post)
          interpolator.populate_value_for('key_1', 'password')
          interpolator.populate_value_for('key_2', nil)
          interpolator.populate_value_for('key_3', 'anything')
          interpolator.populate_value_for('((key_4)', 'password')
        end
      end

      context 'password generation' do
        let (:type) { 'password'}
        let (:key) { '((smurf_password))'}
        let(:response_body) { {'value'=> 'very_secret'} }
        let(:mock_response) do
          response = MockSuccessResponse.new
          response.body = response_body.to_json
          response
        end

        context 'when key already exists in config server' do
          before do
            allow(http_client).to receive(:get).with('smurf_password').and_return(mock_response)
          end
          it 'does NOT make a call to generate_password' do
            expect(http_client).to_not receive(:post)
            interpolator.populate_value_for(key, type)
          end
        end

        context 'when key does NOT exist in config server' do
          before do
            allow(http_client).to receive(:get).with('smurf_password').and_return(MockFailedResponse.new)
          end
          it 'makes a call to generate_password with trimmed key' do
            expect(http_client).to receive(:post).with('smurf_password', {'type' => 'password'}).and_return(MockSuccessResponse.new)
            interpolator.populate_value_for(key, type)
          end
        end
      end

      context "when type is not the string 'password'" do
        it 'does NOT contact the config server' do
          expect(http_client).to_not receive(:get)
          expect(http_client).to_not receive(:post)
          interpolator.populate_value_for('my_db_name', 'hello')
          interpolator.populate_value_for('my_db_name', nil)
          interpolator.populate_value_for('my_db_name', '')
        end
      end

      context 'when type is password' do
        let (:type) { 'password'}
        let (:key) { '((smurf_password))'}
        let(:response_body) { {'value'=> 'very_secret'} }
        let(:mock_response) { generate_success_response(response_body.to_json) }

        context 'when config server post response is not successful' do
          before do
            allow(http_client).to receive(:get).with('smurf_password').and_return(MockFailedResponse.new)
            allow(http_client).to receive(:post).with('smurf_password', {'type' => 'password'}).and_return(MockFailedResponse.new)
          end

          it 'raises an error' do
            expect{
              interpolator.populate_value_for(key, type)
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
            interpolator.populate_value_for(key, type)
          end
        end

        context 'when key does NOT exist in config server' do
          before do
            allow(http_client).to receive(:get).with('smurf_password').and_return(MockFailedResponse.new)
          end
          it 'makes a call to generate_password with trimmed key' do
            expect(http_client).to receive(:post).with('smurf_password', {'type' => 'password'}).and_return(MockSuccessResponse.new)
            interpolator.populate_value_for(key, type)
          end
        end
      end
    end
  end

  describe DummyInterpolator do

    subject(:dummy_interpolator) { DummyInterpolator.new }

    describe '#interpolate' do
      let(:src) do
        {
          'test' => 'smurf',
          'test2' => '((placeholder))'
        }
      end

      it 'returns src as is' do
        expect(dummy_interpolator.interpolate(src)).to eq(src)
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
        expect(dummy_interpolator).to respond_to(:populate_value_for).with(2).arguments
      end
    end

  end
end