require 'spec_helper'

module Bosh::Director::ConfigServer
  describe DeploymentHTTPClient do
    subject(:client) { DeploymentHTTPClient.new(deployment_name, http_client) }
    let(:deployment_name) { nil }
    let(:director_name) { 'smurf_director_name' }
    let(:deployment_name) { 'deployment_name' }
    let(:logger) { double('Logging::Logger') }
    let!(:deployment_model) { Bosh::Director::Models::Deployment.make(name: deployment_name) }
    let(:http_client) { double('Bosh::Director::ConfigServer::HTTPClient') }

    def prepend_namespace(name)
      "/#{director_name}/#{deployment_name}/#{name}"
    end

    def generate_success_response(body)
      result = SampleSuccessResponse.new
      result.body = body
      result
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

    before do
      allow(logger).to receive(:info)
    end

    describe '#get' do
      let(:deployment_name) { "zaks_deployment" }
      subject { client }

      let(:integer_placeholder) { {'data' => [{'name' => "/#{director_name}/#{deployment_name}/integer_placeholder", 'value' => 123, 'id' => '1'}]} }
      let(:instance_placeholder) { {'data' => [{'name' => "/#{director_name}/#{deployment_name}/instance_placeholder", 'value' => 'test1', 'id' => '2'}]} }
      let(:job_placeholder) { {'data' => [{'name' => "/#{director_name}/#{deployment_name}/job_placeholder", 'value' => 'test2', 'id' => '3'}]} }
      let(:env_placeholder) { {'data' => [{'name' => "/#{director_name}/#{deployment_name}/env_placeholder", 'value' => 'test3', 'id' => '4'}]} }
      let(:cert_placeholder) { {'data' => [{'name' => "/#{director_name}/#{deployment_name}/cert_placeholder", 'value' => {'ca' => 'ca_value', 'private_key'=> 'abc123'}, 'id' => '5'}]} }
      let(:mock_config_store) do
        {
          prepend_namespace('integer_placeholder') => generate_success_response(integer_placeholder.to_json),
          prepend_namespace('instance_placeholder') => generate_success_response(instance_placeholder.to_json),
          prepend_namespace('job_placeholder') => generate_success_response(job_placeholder.to_json),
          prepend_namespace('env_placeholder') => generate_success_response(env_placeholder.to_json),
          prepend_namespace('cert_placeholder') => generate_success_response(cert_placeholder.to_json),
        }
      end

      let(:mock_response) do
        response = MockSuccessResponse.new
        response.body = 'some_response'
        response
      end


      before do
        mock_config_store.each do |name, value|
          allow(http_client).to receive(:get).with(name).and_return(value)
        end
      end

      it 'saves responses' do
        [integer_placeholder, job_placeholder, env_placeholder, cert_placeholder].each do |placeholder|
          subject.get(placeholder['data'][0]['name'])
        end

        mappings = Bosh::Director::Models::PlaceholderMapping.all

        expect(mappings.count).to eq(4)

        [integer_placeholder, job_placeholder, env_placeholder, cert_placeholder].each do |placeholder|
          received_mapping = mappings.select { |mapping| mapping.placeholder_id == placeholder['data'][0]['id'] }.first
          expect(received_mapping.placeholder_name).to eq(placeholder['data'][0]['name'])
        end
      end

      context 'when the value is not present on config server' do
        before do
          allow(http_client).to receive(:get).with('zak is cool').and_return(SampleNotFoundResponse.new)
        end

        it 'does not save response' do
          subject.get('zak is cool')

          mappings = Bosh::Director::Models::PlaceholderMapping.all
          expect(mappings.count).to eq(0)
        end
      end
    end

    describe '#post' do
      it 'calls the http client without doing anything else' do
        expect(http_client).to receive(:post).with('is also cool').and_return(generate_success_response('success!'))
        expect(subject.post('is also cool').body).to eq('success!')
      end
    end
  end
end

