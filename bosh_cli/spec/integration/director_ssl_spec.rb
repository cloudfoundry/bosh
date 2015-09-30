require 'spec_helper'

describe 'Director client', vcr: {cassette_name: 'director-https'} do
  # cassete is recorded by running bosh director locally with nginx
  # $ cd bosh-director; be bin/bosh-director -c config/bosh-director.yml
  # start nginx the way integration test start it, point it to director on 8080 and change its port to 8081
  # $ tmp/integration-nginx/sbin/nginx -c tmp/integration-tests-workspace/pid-10473/sandbox/nginx.conf
  # add 'record: :all' to the vcr options to re-record
  let(:director) do
    Bosh::Cli::Client::Director.new(
      user_provided_director_url,
      nil,
      ca_cert: ca_cert)
  end
  let(:config) { Bosh::Cli::Config.new(config_file) }

  let(:config_file) { Tempfile.new('director-integration-spec') }
  after { FileUtils.rm_rf(config_file) }

  let(:valid_cert_path) { File.expand_path('../../assets/ca_certs/client_ca_cert.pem', __FILE__) }
  let(:invalid_cert_path) { File.expand_path('../../assets/ca_certs/invalid_client_ca_cert.pem', __FILE__) }

  context 'when director is running in HTTPS mode' do
    let(:director_url) { 'https://localhost:8081' }

    context 'when user provided HTTPS URL' do
      let(:user_provided_director_url) { 'https://localhost:8081' }

      context 'when user provided correct certificate' do
        let(:ca_cert) { valid_cert_path }

        it 'works' do
          response_code, _, _ = director.get('/info')
          expect(response_code).to eq(200)
        end
      end

      context 'when user provided incorrect certificate' do
        let(:ca_cert) { invalid_cert_path }

        it 'works' do
          expect {
            director.get('/info')
          }.to raise_error 'Invalid SSL Cert for \'https://127.0.0.1:8081/info\': PEM lib'
        end
      end

      context 'when user provided invalid path certificate' do
        let(:ca_cert) { File.expand_path('../invalid_path.pem', __FILE__) }

        it 'fails' do
          expect {
            director.get('/info')
          }.to raise_error 'Invalid ca certificate path'
        end
      end

      context 'when user did not provide certificate' do
        let(:ca_cert) { nil }

        it 'skips ssl verification' do
          response_code, _, _ = director.get('/info')
          expect(response_code).to eq(200)
        end
      end
    end
  end

  context 'when director is running in HTTP mode' do
    let(:director_url) { 'http://localhost:8080' }

    context 'when user provided HTTP URL' do
      let(:user_provided_director_url) { 'http://localhost:8080' }

      context 'when user provided certificate' do
        let(:ca_cert) { valid_cert_path }

        it 'fails' do
          expect {
            director.get('/info')
          }.to raise_error Bosh::Cli::CliError, 'CA certificate cannot be used with HTTP protocol'
        end
      end

      context 'when user did not provide certificate' do
        let(:ca_cert) { nil }

        it 'works' do
          response_code, _, _ = director.get('/info')
          expect(response_code).to eq(200)
        end
      end
    end
  end
end
