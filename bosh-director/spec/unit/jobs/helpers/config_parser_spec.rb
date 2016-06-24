require 'spec_helper'
require 'net/http'

module Bosh::Director
  module Jobs::Helpers
    describe ConfigParser do

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

      describe '#parse' do

        let(:mock_config_store) do
          {
            'bla' => {value: 123},
            'secret_key' => {value: '234'},
            'nuclear_launch_code' => {value: '!@#'},
            'my_db_passwd' => {value: 'dbpass'},
            'secret2' => {value: 'superduper'}
          }
        end

        let(:global_props) do
          {'a' => 'test', 'b' => '((bla))'}
        end

        let(:instance_groups_props) do
          {'a' => ['123', 45, '((secret_key))']}
        end

        let(:job_props) do
          {'a' => {'b' => {'c' => '((nuclear_launch_code))'}}}
        end

        let(:env) do
          {
            'a' => 'public',
            'b' => [{'f' => '((my_db_passwd))'}, ['public', '((secret2))']]
          }
        end

        let(:manifest) do
          {
            'name' => 'test_manifest',
            'resource_pools' => [
              'name' => 'rp',
              'env' => env
            ],
            'instance_groups' => [
              {
                'name' => 'db',
                'jobs' => [
                  {'name' => 'mysql', 'template' => 'template1', 'properties' => job_props}
                ],
                'properties' => instance_groups_props
              }
            ],
            'properties' => global_props
          }
        end

        let(:bad_manifest) do
          {
            'name' => '((nonexistent_name))'
          }
        end

        let(:parsed_manifest) { ConfigParser.parse(manifest) }

        before do
          allow(Bosh::Director::Config).to receive(:config_server_url).and_return("http://127.0.0.1:8080")

          allow(Net::HTTP).to receive(:get_response) do |args|
            key = args.to_s.split('/').last
            value = mock_config_store[key]

            if value.nil?
              MockFailedResponse.new
            else
              response = MockSuccessResponse.new
              response.body = value.to_json
              response
            end
          end
        end

        it 'should replace config placeholders for global properties' do
          global_props = parsed_manifest['properties']

          expect(global_props).to eq({'a' => 'test', 'b' => 123})
        end

        it 'should replace config placeholders for `env`' do
          env_props = parsed_manifest['resource_pools'][0]['env']
          expected = {
            'a' => 'public',
            'b' => [{'f' => 'dbpass'}, ['public', 'superduper']]
          }

          expect(env_props).to eq(expected)
        end

        it 'should replace config placeholders for instance group properties' do
          instance_group_props = parsed_manifest['instance_groups'][0]['properties']

          expect(instance_group_props).to eq({'a' => ['123', 45, '234']})
        end

        it 'should replace config placeholders for jobs properties' do
          job_props = parsed_manifest['instance_groups'][0]['jobs'][0]['properties']
          expected = {'a' => {'b' => {'c' => '!@#'}}}

          expect(job_props).to eq(expected)
        end

        it 'should raise an exception when key is not found' do
          expect { ConfigParser.parse(bad_manifest) }.to raise_error(/Failed to find keys in the config server: nonexistent_name/)
        end
      end
    end
  end
end
