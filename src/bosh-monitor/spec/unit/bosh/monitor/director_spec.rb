require 'spec_helper'

describe 'Bosh::Monitor::Director' do
  include_context Async::RSpec::Reactor
  include Support::UaaHelpers

  # Director client uses event loop and fibers to perform HTTP queries asynchronosuly.
  # However we don't test that here, we only test the synchronous interface.
  # This is way overmocked so it needs an appropriate support from integration tests.
  let(:logger) { instance_double("Logger") }
  subject(:director) do
    Bosh::Monitor::Director.new(
      {
        'endpoint' => 'http://localhost:8080/director',
        'user' => 'admin',
        'password' => 'admin',
        'client_id' => 'hm',
        'client_secret' => 'secret',
        'ca_cert' => 'fake-ca-cert',
      }, logger
    )
  end

  let(:deployments) { [{ 'name' => 'a' }, { 'name' => 'b' }] }
  let(:resurrection_config) { [{ 'content' => '--- {}', 'id' => '1', 'type' => 'resurrection', 'name' => 'some-name' }] }
  let(:auth_provider) { double }

  before do
    # Stub the sleep method to avoid actual waiting in tests
    allow_any_instance_of(Bosh::Monitor::Director).to receive(:sleep).and_return(0)
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

      expect(director.deployments).to eq(deployments)
    end

    it 'can fetch resurrection config from BOSH director' do
      stub_request(:get, 'http://localhost:8080/director/configs?latest=true&type=resurrection')
        .with(basic_auth: %w[admin admin])
        .to_return(body: json_dump(resurrection_config), status: 200)

      expect(director.resurrection_config).to eq(resurrection_config)
    end

    it 'raises an error if resurrection config cannot be fetched' do
      stub_request(:get, 'http://localhost:8080/director/configs?latest=true&type=resurrection')
        .with(basic_auth: %w[admin admin])
        .to_return(body: 'foo', status: 500)

      expect { director.resurrection_config }
        .to raise_error(
          Bosh::Monitor::DirectorError,
          'Cannot get resurrection config from director at'\
          ' http://localhost:8080/director/configs?type=resurrection&latest=true: 500 foo',
        )
    end

    it 'raises an error if deployments cannot be fetched' do
      stub_request(:get, 'http://localhost:8080/director/deployments?exclude_configs=true&exclude_releases=true&exclude_stemcells=true')
        .with(basic_auth: %w[admin admin])
        .to_return(body: 'foo', status: 500)

      expect do
        director.deployments
      end.to raise_error(
        Bosh::Monitor::DirectorError,
        'Cannot get deployments from director at ' \
        'http://localhost:8080/director/deployments?exclude_configs=true&exclude_releases=true&exclude_stemcells=true: 500 foo',
      )
    end

    it 'can fetch instances by deployment name from BOSH director' do
      stub_request(:get, 'http://localhost:8080/director/deployments/foo/instances')
        .with(basic_auth: %w[admin admin])
        .to_return(body: json_dump(deployments), status: 200)

      expect(director.get_deployment_instances('foo')).to eq(deployments)
    end

    it 'raises an error if instances by deployment name cannot be fetched' do
      stub_request(:get, 'http://localhost:8080/director/deployments/foo/instances')
        .with(basic_auth: %w[admin admin])
        .to_return(body: 'foo', status: 500)

      expect do
        expect(director.get_deployment_instances('foo')).to eq(deployments)
      end.to raise_error(
        Bosh::Monitor::DirectorError,
        'Cannot get deployment \'foo\' from director at ' \
        'http://localhost:8080/director/deployments/foo/instances: 500 foo',
      )
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
      expect(director.deployments).to eq(deployments)
    end
  end

  describe '#get_deployment_instances_full' do
    before do
      stub_request(:get, 'http://localhost:8080/director/info')
        .to_return(body: json_dump({}), status: 200)
    end
    context 'when the task succeeds with state done' do
      let(:task_location) { '/task/123' }
      let(:task_result) { "{\"vm\": \"details1\"}\n{\"vm\": \"details2\"}\n" }
      let(:auth_header) { { 'Authorization' => 'Basic YWRtaW46YWRtaW4=', 'Accept-Encoding' => 'gzip' } }

      before do
        # Stub initial request to get task location
        stub_request(:get, "http://localhost:8080/director/deployments/foo/instances?format=full")
        .with(headers: auth_header)
        .with(basic_auth: %w[admin admin])
        .to_return(status: 200, headers: { 'location' => task_location })

        # Stub requests for task status
        stub_request(:get, "http://localhost:8080/director#{task_location}")
        .with(headers: auth_header)
        .to_return(
        { status: 206, body: "" },
        { status: 200, body: '{"state":"done"}' }
        )

        # Stub final request to get task result
        stub_request(:get, "http://localhost:8080/director#{task_location}/output?type=result")
        .with(headers: auth_header)
        .to_return(status: 200, body: task_result)
      end

      it 'returns parsed instance details' do
        allow(Logging).to receive(:logger).and_return(logger)
        allow(logger).to receive(:warn)
        expect(director.get_deployment_instances_full('foo')).to eq([{"vm"=>"details1"}, {"vm"=>"details2"}])
      end
    end

    context 'when the task fails with an error state' do
      let(:task_location) { '/task/123' }
      let(:auth_header) { { 'Authorization' => 'Basic YWRtaW46YWRtaW4=', 'Accept-Encoding' => 'gzip' } }
      before do
        # Stub request to get instance info leading to a task
        stub_request(:get, "http://localhost:8080/director/deployments/foo/instances?format=full")
        .with(headers: auth_header)
        .to_return(status: 302, headers: { 'location' => task_location })
        
        # Stub task status checks
        stub_request(:get, "http://localhost:8080/director#{task_location}")
        .with(headers: auth_header)
        .to_return(
        { status: 200, body: '{"state":"queued"}' },
        { status: 200, body: '{"state":"processing"}' },
        { status: 200, body: '{"state":"error"}' } # Simulate eventual 'error' state
        )
        
        # Final stub to avoid errors on log completion attempt
        stub_request(:get, "http://localhost:8080/director#{task_location}/output?type=result")
        .with(headers: auth_header)
        .to_return(status: 500, body: '') # Simulate failure response on output fetch
      end
    
      it 'logs a warning and returns nil' do
        allow(Logging).to receive(:logger).and_return(logger)
        allow(logger).to receive(:warn)
        expect(logger).to receive(:warn).with(/The number of retries to fetch instance details for deployment/)
        result, state = director.get_deployment_instances_full('foo', 1)
        expect(result).to be_nil
        expect(state).to eq('error')
      end
    end

    context 'when task location cannot be found' do
      let(:auth_header) { { 'Authorization' => 'Basic YWRtaW46YWRtaW4=', 'Accept-Encoding' => 'gzip' } }
      before do
        stub_request(:get, "http://localhost:8080/director/deployments/foo/instances?format=full")
        .with(headers: auth_header)
        .with(basic_auth: %w[admin admin])
        .to_return(status: 200)
      end

      it 'raises a DirectorError' do
        expect {
        director.get_deployment_instances_full('foo')
        }.to raise_error(Bosh::Monitor::DirectorError, "Can not find 'location' response header to retrieve the task location")
      end
    end

    context 'when task result fetching fails' do
      let(:task_location) { '/task/123' }
      let(:auth_header) { { 'Authorization' => 'Basic YWRtaW46YWRtaW4=', 'Accept-Encoding' => 'gzip' } }

      before do
        # Stub initial request to get task location
        stub_request(:get, "http://localhost:8080/director/deployments/foo/instances?format=full")
        .with(headers: auth_header)
        .with(basic_auth: %w[admin admin])
        .to_return(status: 200, headers: { 'location' => task_location })

        # Stub requests for task status
        stub_request(:get, "http://localhost:8080/director#{task_location}")
        .with(headers: auth_header)
        .to_return(status: 200, body: '{"state":"done"}')

        # Stub final request to get task result
        stub_request(:get, "http://localhost:8080/director#{task_location}/output?type=result")
        .with(headers: auth_header)
        .to_return(status: 500, body: 'error message')
      end

      it 'raises a DirectorError' do
        allow(Logging).to receive(:logger).and_return(logger)
        allow(logger).to receive(:warn)
        expect {
        director.get_deployment_instances_full('foo')
        }.to raise_error(Bosh::Monitor::DirectorError, "Fetching full instance details for deployment 'foo' failed")
      end
    end
  end


  def json_dump(data)
    JSON.dump(data)
  end
end
