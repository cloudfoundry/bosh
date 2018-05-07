# frozen_string_literal: true

require 'rspec'
require 'yaml'
require 'bosh/template/evaluation_context'
require 'json'

describe 'registry.yml.erb' do
  let(:deployment_manifest_fragment) do
    {
      'properties' => {
        'registry' => {
          'port' => 80,
          'username' => 'user',
          'password' => 'password',
          'http' => {
            'port' => 80,
            'user' => 'user',
            'password' => 'password'
          },
          'db' => {
            'adapter' => 'mysql2',
            'user' => 'ub45391e00',
            'password' => 'p4cd567d84d0e012e9258d2da30',
            'host' => 'bosh.hamazonhws.com',
            'port' => 3306,
            'database' => 'bosh',
            'connection_options' => {
              'max_connections' => 32
            },
            'tls' => {
              'enabled' => false,
              'cert' => {
                'ca' => '/var/vcap/jobs/registry/config/db/ca.pem',
              },
            },
          },
        }
      }
    }
  end

  let(:erb_yaml) { File.read(File.join(File.dirname(__FILE__), '../jobs/registry/templates/registry.yml.erb')) }

  subject(:parsed_yaml) do
    binding = Bosh::Template::EvaluationContext.new(deployment_manifest_fragment, nil).get_binding
    YAML.safe_load(ERB.new(erb_yaml).result(binding))
  end

  shared_examples :database_options do
    it 'renders database properties' do
      expect(parsed_yaml['db']).to eq(
        'adapter' => 'mysql2',
        'user' => 'ub45391e00',
        'password' => 'p4cd567d84d0e012e9258d2da30',
        'host' => 'bosh.hamazonhws.com',
        'port' => 3306,
        'database' => 'bosh',
        'connection_options' => {
          'max_connections' => 32
        },
        'tls' => {
          'enabled' => false,
          'cert' => {
            'ca' => '/var/vcap/jobs/registry/config/db/ca.pem',
            'certificate' => '/var/vcap/jobs/registry/config/db/client_certificate.pem',
            'private_key' => '/var/vcap/jobs/registry/config/db/client_private_key.key',
          },
          'bosh_internal' => {
            'ca_provided' => true,
            'mutual_tls_enabled' => false,
          },
        }
      )
    end
  end

  context 'db tls' do
    it 'passes correct path for database ca cert, client cert, and client private key' do
      expect(parsed_yaml['db']['tls']['cert']['ca']).to eq('/var/vcap/jobs/registry/config/db/ca.pem')
      expect(parsed_yaml['db']['tls']['cert']['certificate']).to eq('/var/vcap/jobs/registry/config/db/client_certificate.pem')
      expect(parsed_yaml['db']['tls']['cert']['private_key']).to eq('/var/vcap/jobs/registry/config/db/client_private_key.key')
    end

    context 'when registry.db.tls.enabled is true' do
      before do
        deployment_manifest_fragment['properties']['registry']['db']['tls']['enabled'] = true
      end

      it 'configures enabled TLS for database property' do
        expect(parsed_yaml['db']['tls']['enabled']).to be_truthy
      end
    end

    context 'when registry.db.tls.enabled is false' do
      before do
        deployment_manifest_fragment['properties']['registry']['db']['tls']['enabled'] = false
      end

      it 'configures disables TLS for database property' do
        expect(parsed_yaml['db']['tls']['enabled']).to be_falsey
      end
    end

    context 'when registry.db.tls.enabled is not defined' do
      before do
        deployment_manifest_fragment['properties']['registry']['db']['tls'].delete('enabled')
      end

      it 'disables TLS by default' do
        expect(parsed_yaml['db']['tls']['enabled']).to be_falsey
      end
    end

    context 'when registry.db.tls.cert.ca is provided' do
      it 'set bosh_internal ca_provided to true' do
        expect(parsed_yaml['db']['tls']['bosh_internal']['ca_provided']).to be_truthy
      end
    end

    context 'when registry.db.tls.cert.ca is NOT provided' do
      before do
        deployment_manifest_fragment['properties']['registry']['db']['tls']['cert']['ca'] = nil
      end

      it 'set bosh_internal ca_provided to false' do
        expect(parsed_yaml['db']['tls']['bosh_internal']['ca_provided']).to be_falsey
      end
    end

    context 'when registry.db.tls.cert.certificate and registry.db.tls.cert.private_key are provided' do
      before do
        deployment_manifest_fragment['properties']['registry']['db']['tls']['cert']['certificate'] = 'something'
        deployment_manifest_fragment['properties']['registry']['db']['tls']['cert']['private_key'] = 'something secret'
      end

      it 'configures mutual TLS for database' do
        expect(parsed_yaml['db']['tls']['bosh_internal']['mutual_tls_enabled']).to be_truthy
      end
    end

    context 'when registry.db.tls.cert.certificate is NOT provided' do
      before do
        deployment_manifest_fragment['properties']['registry']['db']['tls']['cert']['private_key'] = 'something secret'
      end

      it 'does NOT configure mutual TLS for database' do
        expect(parsed_yaml['db']['tls']['bosh_internal']['mutual_tls_enabled']).to be_falsey
      end
    end

    context 'when registry.db.tls.cert.private_key is NOT provided' do
      before do
        deployment_manifest_fragment['properties']['registry']['db']['tls']['cert']['certificate'] = 'something'
      end

      it 'does NOT configure mutual TLS for database' do
        expect(parsed_yaml['db']['tls']['bosh_internal']['mutual_tls_enabled']).to be_falsey
      end
    end
  end

  context 'registry with multiple users settings' do
    before do
      deployment_manifest_fragment['properties']['registry']['additional_users'] = [
          {'username' => 'admin1', 'password' => 'pass1'},
          {'username' => 'admin2', 'password' => 'pass2'},
      ]
    end
    it 'renders database properties' do
      expect(parsed_yaml['http']['additional_users']).to eq([
          {'username' => 'admin1', 'password' => 'pass1'},
          {'username' => 'admin2', 'password' => 'pass2'},
      ])
      expect(parsed_yaml['http']['user']).to eq('user')
      expect(parsed_yaml['http']['password']).to eq('password')
    end
  end

  context 'aws' do
    before do
      deployment_manifest_fragment['properties']['aws'] = {
        'credentials_source' => 'static',
        'access_key_id' => 'key',
        'secret_access_key' => 'secret',
        'region' => 'region',
        'ec2_endpoint' => 'some_ec2_endpoint',
        'elb_endpoint' => 'some_elb_endpoint',
        'max_retries' => 10,
        'ssl_verify_peer' => false,
        'ssl_ca_file' => '/custom/cert/ca-certificates',
        'ssl_ca_path' => '/custom/cert/'
      }
    end

    it_behaves_like :database_options

    it 'sets plugin to aws' do
      expect(parsed_yaml['cloud']).to include(
        'plugin' => 'aws'
      )
    end

    it 'renders aws properties' do
      expect(parsed_yaml['cloud']['aws']).to eq(
        'credentials_source' => 'static',
        'access_key_id' => 'key',
        'secret_access_key' => 'secret',
        'region' => 'region',
        'ec2_endpoint' => 'some_ec2_endpoint',
        'elb_endpoint' => 'some_elb_endpoint',
        'max_retries' => 10,
        'ssl_verify_peer' => false,
        'ssl_ca_file' => '/custom/cert/ca-certificates',
        'ssl_ca_path' => '/custom/cert/'
      )
    end

    context 'when deployment manifest contains special characters' do
      before do
        deployment_manifest_fragment['properties']['aws'] = {
          'credentials_source' => 'static',
          'access_key_id' => '!key',
          'secret_access_key' => '!secret',
          'region' => '!region',
          'ec2_endpoint' => '!some_ec2_endpoint',
          'elb_endpoint' => '!some_elb_endpoint',
          'max_retries' => 10,
          'ssl_verify_peer' => false,
          'ssl_ca_file' => '/custom/cert/ca-certificates',
          'ssl_ca_path' => '/custom/cert/'
        }
      end

      it 'renders aws properties' do
        expect(parsed_yaml['cloud']['aws']).to eq(
          'credentials_source' => 'static',
          'access_key_id' => '!key',
          'secret_access_key' => '!secret',
          'region' => '!region',
          'ec2_endpoint' => '!some_ec2_endpoint',
          'elb_endpoint' => '!some_elb_endpoint',
          'max_retries' => 10,
          'ssl_verify_peer' => false,
          'ssl_ca_file' => '/custom/cert/ca-certificates',
          'ssl_ca_path' => '/custom/cert/'
        )
      end
    end
  end

  context 'openstack' do
    before do
      deployment_manifest_fragment['properties']['openstack'] = {
        'auth_url' => 'auth_url',
        'username' => 'username',
        'api_key' => 'api_key',
        'tenant' => 'tenant',
      }
    end

    it_behaves_like :database_options

    it 'renders openstack properties' do
      expect(parsed_yaml['cloud']['openstack']).to eq(
        'auth_url' => 'auth_url',
        'username' => 'username',
        'api_key' => 'api_key',
        'tenant' => 'tenant',
      )
    end

    context 'when deployment manifest contains special characters' do
      before do
        deployment_manifest_fragment['properties']['openstack'] = {
          'auth_url' => '!auth_url',
          'username' => '!username',
          'api_key' => '!api_key',
          'tenant' => '!tenant',
        }
      end

      it 'renders openstack properties' do
        expect(parsed_yaml['cloud']['openstack']).to eq(
          'auth_url' => '!auth_url',
          'username' => '!username',
          'api_key' => '!api_key',
          'tenant' => '!tenant',
        )
      end
    end
  end
end
