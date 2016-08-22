require 'spec_helper'

module Bosh::Director::ConfigServer
  describe ConfigParser do

    subject(:parsed_manifest) { ConfigParser.parse(manifest_hash, ignored_subtrees) }

    let(:manifest_hash) { {} }
    let(:ignored_subtrees) {[]}

    context '#parse' do
      let(:mock_config_store) do
        {
          'value' => 123,
          'instance_placeholder' => 'test1',
          'job_placeholder' => 'test2',
          'env_placeholder' => 'test3',
          'name_placeholder' =>'test4'
        }
      end

      let(:http_client) { double('Bosh::Director::ConfigServer::HTTPClient') }

      before do
        expect(HTTPClient).to receive(:new).and_return(http_client)
        mock_config_store.each do |key, value|
          allow(http_client).to receive(:get_value_for_key).with(key).and_return(value)
        end
      end

      it 'should return a new copy of the original manifest' do
        expect(parsed_manifest).to_not equal(manifest_hash)
      end

      it 'should request keys from the proper url' do
        manifest_hash['properties'] = { 'key' => '((value))' }
        parsed_manifest
      end

      it 'should replace any top level property key in the passed hash' do
        manifest_hash['name'] = '((name_placeholder))'

        expected_manifest = {
          'name' => 'test4'
        }

        expect(parsed_manifest).to eq(expected_manifest)
      end

      it 'should replace the global property keys in the passed hash' do
        manifest_hash['properties'] = { 'key' => '((value))' }

        expected_manifest = {
          'properties' => { 'key' => 123 }
        }

        expect(parsed_manifest).to eq(expected_manifest)
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

        expect(parsed_manifest).to eq(expected_manifest)
      end

      it 'should replace the env keys in the passed hash' do
        manifest_hash['resource_pools'] =  [ {'env' => {'env_prop' => '((env_placeholder))'} } ]

        expected_manifest = {
          'resource_pools' => [ {'env' => {'env_prop' => 'test3'} } ]
        }

        expect(parsed_manifest).to eq(expected_manifest)
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

        expect(parsed_manifest).to eq(expected_manifest)
      end

      it 'should raise an error message when key is missing from the config_server' do
        allow(http_client).to receive(:get_value_for_key).with('missing_placeholder').and_raise(Bosh::Director::ConfigServerMissingKeys)

        manifest_hash['properties'] = { 'key' => '((missing_placeholder))' }
        expect{
          parsed_manifest
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

        expect(parsed_manifest).to eq(expected_manifest)
      end


    end
  end
end