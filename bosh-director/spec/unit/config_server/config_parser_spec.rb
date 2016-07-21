require 'spec_helper'

module Bosh::Director::ConfigServer
  describe ConfigParser do

    subject(:parsed_manifest) { ConfigParser.parse(manifest_hash, ignored_subtrees) }

    let(:manifest_hash) { {} }
    let(:ignored_subtrees) {[]}

    context '#parse' do
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
        @mock_http = double("Net::HTTP")

        allow(Net::HTTP).to receive(:new) do |_|
          @mock_http
        end

        allow(@mock_http).to receive(:use_ssl=)
        allow(@mock_http).to receive(:verify_mode=)

        allow(@mock_http).to receive(:get) do |args|
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

      context 'ca_cert file exists and is not empty' do
        before do
          allow(@mock_http).to receive(:ca_file=).with(any_args)
          allow(Bosh::Director::Config).to receive(:config_server_cert_path).and_return("/root/cert.crt")
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:read).and_return("my-fake-content")
        end

        it 'should use https when trying to fetch values' do
          manifest_hash['properties'] = { 'key' => '((value))' }
          expect(@mock_http).to receive(:use_ssl=).with(true)
          expect(@mock_http).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
          expect(@mock_http).to receive(:ca_file=).with('/root/cert.crt')
          parsed_manifest
        end

        it 'should return a new copy of the original manifest' do
          expect(parsed_manifest).to_not equal(manifest_hash)
        end

        it 'should request keys from the proper url' do
          manifest_hash['properties'] = { 'key' => '((value))' }
          expect(@mock_http).to receive(:get).with("/v1/data/value")
          parsed_manifest
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

          expect(parsed_manifest).to eq(expected_manifest)
        end

        it 'should replace the env keys in the passed hash' do
          manifest_hash['resource_pools'] =  [ {'env' => {'env_prop' => '((env_val))'} } ]

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

          expect(parsed_manifest).to eq(expected_manifest)
        end

        it 'should raise an error message when the certificate is invalid' do
          allow(@mock_http).to receive(:get).and_raise(OpenSSL::SSL::SSLError)
          manifest_hash['properties'] = { 'key' => '((value))' }
          expect{ parsed_manifest }.to raise_error('SSL certificate verification failed')
        end

        it 'should not replace values in ignored subtrees' do
          ignored_subtrees << ['instance_groups', Numeric.new, 'jobs', Numeric.new, 'uninterpolated_properties']

          manifest_hash['instance_groups'] = [
            {
              'name' => 'bla',
              'jobs' => [
                {
                  'name' => 'test_job',
                  'properties' => { 'job_prop' => '((job_val))' },
                  'uninterpolated_properties' => { 'job_prop' => '((job_val))' }
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
                    'properties' => { 'job_prop' => 'test2' },
                    'uninterpolated_properties' => { 'job_prop' => '((job_val))' },
                  }
                ]
              }
            ]
          }

          expect(parsed_manifest).to eq(expected_manifest)
        end
      end

      shared_examples 'cert_store' do
        store_double = nil

        before do
          store_double = instance_double(OpenSSL::X509::Store)
          allow(store_double).to receive(:set_default_paths)
          allow(OpenSSL::X509::Store).to receive(:new).and_return(store_double)
          allow(@mock_http).to receive(:cert_store=)
        end

        it 'uses default cert_store' do
          manifest_hash['properties'] = { 'key' => '((value))' }
          parsed_manifest

          expect(@mock_http).to have_received(:cert_store=)
          expect(store_double).to have_received(:set_default_paths)
        end
      end

      context 'ca_cert file does not exist' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_cert_path).and_return('')
        end
        it_behaves_like 'cert_store'
      end

      context 'ca_cert file exists and is empty' do
        before do
          allow(Bosh::Director::Config).to receive(:config_server_cert_path).and_return("/root/cert.crt")
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:read).and_return('')
        end

        it_behaves_like 'cert_store'
      end
    end
  end
end