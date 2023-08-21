require_relative '../../../spec_helper'

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
        'ca_cert' => 'fake-ca-cert',
      }, double(:logger)
    )
  end

  let(:deployments) { [{ 'name' => 'a' }, { 'name' => 'b' }] }
  let(:resurrection_config) { [{ 'content' => '--- {}', 'id' => '1', 'type' => 'resurrection', 'name' => 'some-name' }] }

  before do
    allow_any_instance_of(EventMachine::WebMockHttpClient).to receive(:uri).and_raise('This method was removed from the non-mocked EventMachine::HttpClient in the version of EventMachine we are using. WebMock has not been updated to reflect this reality.')
  end

  context 'when director is running in non-UAA mode' do
    before do
      stub_request(:get, 'http://localhost:8080/director/info')
        .to_return(body: json_dump({}), status: 200)
    end

    it 'can fetch deployments from BOSH director' do
      stub_request(:get, 'http://localhost:8080/director/deployments?exclude_configs=true&exclude_releases=true&exclude_stemcells=true')
        .with(basic_auth: %w[admin admin])
        .to_return(body: json_dump(deployments), status: 200)

      with_fiber do
        expect(director.deployments).to eq(deployments)
      end
    end

    it 'can fetch resurrection config from BOSH director' do
      stub_request(:get, 'http://localhost:8080/director/configs?latest=true&type=resurrection')
        .with(basic_auth: %w[admin admin])
        .to_return(body: json_dump(resurrection_config), status: 200)

      with_fiber do
        expect(director.resurrection_config).to eq(resurrection_config)
      end
    end

    it 'raises an error if resurrection config cannot be fetched' do
      stub_request(:get, 'http://localhost:8080/director/configs?latest=true&type=resurrection')
        .with(basic_auth: %w[admin admin])
        .to_return(body: 'foo', status: 500)

      with_fiber do
        expect { director.resurrection_config }
          .to raise_error(
            Bhm::DirectorError,
            'Cannot get resurrection config from director at'\
            ' http://localhost:8080/director/configs?type=resurrection&latest=true: 500 foo',
          )
      end
    end

    it 'raises an error if deployments cannot be fetched' do
      stub_request(:get, 'http://localhost:8080/director/deployments?exclude_configs=true&exclude_releases=true&exclude_stemcells=true')
        .with(basic_auth: %w[admin admin])
        .to_return(body: 'foo', status: 500)

      with_fiber do
        expect do
          director.deployments
        end.to raise_error(
          Bhm::DirectorError,
          'Cannot get deployments from director at ' \
          'http://localhost:8080/director/deployments?exclude_configs=true&exclude_releases=true&exclude_stemcells=true: 500 foo',
        )
      end
    end

    it 'can fetch instances by deployment name from BOSH director' do
      stub_request(:get, 'http://localhost:8080/director/deployments/foo/instances')
        .with(basic_auth: %w[admin admin])
        .to_return(body: json_dump(deployments), status: 200)

      with_fiber do
        expect(director.get_deployment_instances('foo')).to eq(deployments)
      end
    end

    it 'raises an error if instances by deployment name cannot be fetched' do
      stub_request(:get, 'http://localhost:8080/director/deployments/foo/instances')
        .with(basic_auth: %w[admin admin])
        .to_return(body: 'foo', status: 500)

      with_fiber do
        expect do
          expect(director.get_deployment_instances('foo')).to eq(deployments)
        end.to raise_error(
          Bhm::DirectorError,
          'Cannot get deployment \'foo\' from director at ' \
          'http://localhost:8080/director/deployments/foo/instances: 500 foo',
        )
      end
    end
  end

  context 'when director is running in UAA mode' do
    before do
      token_issuer = instance_double(CF::UAA::TokenIssuer)

      allow(File).to receive(:exist?).with('fake-ca-cert').and_return(true)
      allow(File).to receive(:read).with('fake-ca-cert').and_return('test')

      allow(CF::UAA::TokenIssuer).to receive(:new).with(
        'http://localhost:8080/uaa',
        'hm',
        'secret',
        { ssl_ca_file: 'fake-ca-cert' },
      ).and_return(token_issuer)
      token = uaa_token_info('fake-token-id')
      allow(token_issuer).to receive(:client_credentials_grant).and_return(token)

      uaa_status = {
        'user_authentication' => {
          'type' => 'uaa',
          'options' => {
            'url' => 'http://localhost:8080/uaa',
          },
        },
      }

      stub_request(:get, 'http://localhost:8080/director/info')
        .to_return(body: json_dump(uaa_status), status: 200)

      stub_request(:get, 'http://localhost:8080/director/deployments?exclude_configs=true&exclude_releases=true&exclude_stemcells=true')
        .with(headers: { 'Authorization' => token.auth_header })
        .to_return(body: json_dump(deployments), status: 200)
    end

    it 'can fetch deployments from BOSH director' do
      with_fiber do
        expect(director.deployments).to eq(deployments)
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
