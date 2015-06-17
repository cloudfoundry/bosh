require 'spec_helper'

describe 'Bhm::Director' do
  include Support::UaaHelpers

  # Director client uses event loop and fibers to perform HTTP queries asynchronosuly.
  # However we don't test that here, we only test the synchronous interface.
  # This is way overmocked so it needs an appropriate support from integration tests.
  subject(:director) do
    Bhm::Director.new(
      {
        'endpoint' => 'http://localhost:8080/director',
        'user' => 'admin',
        'password' => 'admin',
        'client_id' => 'hm',
        'client_secret' => 'secret',
        'ca_cert' => 'fake-ca-cert'
      }, double(:logger)
    )
  end

  let(:deployments) { [{ 'name' => 'a'}, { 'name' => 'b'}] }

  context 'when director is running in non-UAA mode' do
    before do
      stub_request(:get, 'http://localhost:8080/director/info').
        to_return(:body => json_dump({}), :status => 200)
    end

    it 'can fetch deployments from BOSH director' do
      stub_request(:get, 'http://localhost:8080/director/deployments').
        with(:headers => {'Authorization' => ['admin', 'admin']}).
        to_return(:body => json_dump(deployments), :status => 200)

      with_fiber do
        expect(director.get_deployments).to eq(deployments)
      end
    end

    it 'raises an error if deployments cannot be fetched' do
      stub_request(:get, 'http://localhost:8080/director/deployments').
        with(:headers => {'Authorization' => ['admin', 'admin']}).
        to_return(:body => 'foo', :status => 500)

      with_fiber do
        expect {
          director.get_deployments
        }.to raise_error(Bhm::DirectorError, 'Cannot get deployments from director at http://localhost:8080/director/deployments: 500 foo')
      end
    end

    it 'can fetch deployment by name from BOSH director' do
      stub_request(:get, 'http://localhost:8080/director/deployments/foo/vms').
        with(:headers => {'Authorization' => ['admin', 'admin']}).
        to_return(:body => json_dump(deployments), :status => 200)

      with_fiber do
        expect(director.get_deployment_vms('foo')).to eq(deployments)
      end
    end
  end

  context 'when director is running in UAA mode' do
    before do
      token_issuer = instance_double(CF::UAA::TokenIssuer)
      allow(CF::UAA::TokenIssuer).to receive(:new).with(
          'http://localhost:8080/uaa',
          'hm',
          'secret',
          { ssl_ca_file: 'fake-ca-cert' }
        ).and_return(token_issuer)
      token = uaa_token_info('fake-token-id')
      allow(token_issuer).to receive(:client_credentials_grant).and_return(token)

      uaa_status = {
        'user_authentication' => {
          'type' => 'uaa',
          'options' => {
            'url' => 'http://localhost:8080/uaa'
          }
        }
      }

      stub_request(:get, 'http://localhost:8080/director/info').
        to_return(:body => json_dump(uaa_status), :status => 200)

      stub_request(:get, 'http://localhost:8080/director/deployments').
        with(:headers => {'Authorization' => token.auth_header}).
        to_return(:body => json_dump(deployments), :status => 200)
    end

    it 'can fetch deployments from BOSH director' do
      with_fiber do
        expect(director.get_deployments).to eq(deployments)
      end
    end
  end

  def with_fiber
    EM.run do
      Fiber.new do
        yield
        EM.stop
      end.resume
    end
  end

  def json_dump(data)
    JSON.dump(data)
  end
end
