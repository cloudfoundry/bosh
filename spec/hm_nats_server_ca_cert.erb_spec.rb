require 'rspec'
require 'bosh/template/evaluation_context'
require 'json'

describe 'nats_server_ca.cert.erb' do
  let(:deployment_manifest_fragment) do
    {
      'properties' => {
        'nats' => {
          'cert' => {
            'ca' => '----- BEGIN CERTIFICATE -----\nI am a cert'
          }
        }
      }
    }
  end

  let(:ca_cert_template) { File.read(File.join(File.dirname(__FILE__), '../jobs/health_monitor/templates/nats_server_ca.cert.erb')) }

  subject(:rendered_certificate) do
    binding = Bosh::Template::EvaluationContext.new(deployment_manifest_fragment).get_binding
    ERB.new(ca_cert_template).result(binding)
  end

  context 'given a nats ca cert in the properties' do
    it 'should render the cert contents' do
      expect(rendered_certificate).to eq('----- BEGIN CERTIFICATE -----\nI am a cert')
    end
  end
end
