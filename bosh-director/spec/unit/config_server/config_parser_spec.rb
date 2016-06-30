require 'spec_helper'

module Bosh::Director::ConfigServer
  describe ConfigParser do

    subject(:config_parser) { ConfigParser.new(manifest_hash) }

    let(:manifest_hash) { {} }

    context '#parsed' do

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

      let(:mock_config_store) do
        {
          'value' => {value: 123},
          'instance_val' => {value: 'test1'},
          'job_val' => {value: 'test2'},
          'env_val' => {value: 'test3'},
          'name_val' => {value: 'test4'}
        }
      end

      before do
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

        allow(Bosh::Director::Config).to receive(:config_server_url).and_return("http://127.0.0.1:8080")
      end

      it 'should replace the global property keys in the passed hash' do
        manifest_hash['properties'] = { 'key' => '((value))' }

        expected_manifest = {
          'properties' => { 'key' => 123 }
        }

        expect(config_parser.parsed).to eq(expected_manifest)
      end

      it 'should replace the instance group property keys in the passed hash' do
        manifest_hash['instance_groups'] = [
          {
            'name' => 'bla',
            'properties' => { 'instance_prop' => '((instance_val))' }
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

        expect(config_parser.parsed).to eq(expected_manifest)
      end

      it 'should replace the env keys in the passed hash' do
        manifest_hash['resource_pools'] =  [ {'env' => {'env_prop' => '((env_val))'} } ]

        expected_manifest = {
          'resource_pools' => [ {'env' => {'env_prop' => 'test3'} } ]
        }

        expect(config_parser.parsed).to eq(expected_manifest)
      end

      it 'should replace the job properties in the passed hash' do
        manifest_hash['instance_groups'] = [
          {
            'name' => 'bla',
            'jobs' => [
              {
                'name' => 'test_job',
                'properties' => { 'job_prop' => '((job_val))' }
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

        expect(config_parser.parsed).to eq(expected_manifest)
      end

      it 'should not replace any other paths in the manifest' do
        manifest_hash['instance_groups'] = [
          {
            'name' => '((name_val))',
            'properties' => { 'instance_prop' => '((instance_val))' },
            'jobs' => [
              {
                'name' => 'test_job',
                'properties' => { 'job_prop' => '((job_val))' }
              }
            ]
          }
        ]

        expected_manifest = {
          'instance_groups' => [
            {
              'name' => '((name_val))',
              'properties' => { 'instance_prop' => 'test1' },
              'jobs' => [
                {
                  'name' => 'test_job',
                  'properties' => { 'job_prop' => 'test2' }
                }
              ]
            }
          ]
        }

        expect(config_parser.parsed).to eq(expected_manifest)
      end
    end
  end
end