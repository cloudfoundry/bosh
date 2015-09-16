require 'spec_helper'
require 'bosh/dev/openstack/micro_bosh_deployment_manifest'
require 'yaml'

module Bosh::Dev::Openstack
  describe MicroBoshDeploymentManifest do
    subject { MicroBoshDeploymentManifest.new(env, net_type) }
    let(:env) { {} }
    let(:net_type) { 'dynamic' }

    its(:filename) { should eq('micro_bosh.yml') }

    it 'is writable' do
      expect(subject).to be_a(Bosh::Dev::WritableManifest)
    end

    describe '#to_h' do
      before do
        env.merge!(
          'BOSH_OPENSTACK_VIP_DIRECTOR_IP' => 'vip',
          'BOSH_OPENSTACK_MANUAL_IP' => 'ip',
          'BOSH_OPENSTACK_MICRO_NET_ID' => 'net_id',
          'BOSH_OPENSTACK_AUTH_URL' => 'auth_url',
          'BOSH_OPENSTACK_USERNAME' => 'username',
          'BOSH_OPENSTACK_API_KEY' => 'api_key',
          'BOSH_OPENSTACK_TENANT' => 'tenant',
          'BOSH_OPENSTACK_REGION' => 'region',
          'BOSH_OPENSTACK_PRIVATE_KEY' => 'private_key_path',
          'BOSH_OPENSTACK_DEFAULT_KEY_NAME' => 'key_name',
          'BOSH_OPENSTACK_FLAVOR' => 'flavor',
          'BOSH_OPENSTACK_DEFAULT_SECURITY_GROUP' => 'security_group',
        )
      end

      context 'when net_type is "manual"' do
        let(:net_type) { 'manual' }
        let(:expected_yml) { <<YAML }
---
name: microbosh-openstack-manual

logging:
  level: DEBUG

network:
  type: manual
  vip: vip
  ip: ip
  cloud_properties:
    net_id: net_id

resources:
  persistent_disk: 4096
  cloud_properties:
    instance_type: flavor

cloud:
  plugin: openstack
  properties:
    openstack:
      auth_url: auth_url
      username: username
      api_key: api_key
      tenant: tenant
      region: region
      endpoint_type: publicURL
      default_key_name: key_name
      default_security_groups:
      - security_group
      private_key: private_key_path
      state_timeout: 300
      wait_resource_poll_interval: 5
      connection_options:
        connect_timeout: 60

    # Default registry configuration needed by CPI
    registry:
      endpoint: http://admin:admin@localhost:25889
      user: admin
      password: admin

apply_spec:
  agent:
    blobstore:
      address: vip
    nats:
      address: vip
  properties:
    director:
      max_vm_create_tries: 15
YAML

        it 'generates the correct YAML' do
          expect(subject.to_h).to eq(Psych.load(expected_yml))
        end
      end

      context 'when net_type is "dynamic"' do
        let(:net_type) { 'dynamic' }
        let(:expected_yml) { <<YAML }
---
name: microbosh-openstack-dynamic
logging:
  level: DEBUG
network:
  type: dynamic
  vip: vip
  cloud_properties:
    net_id: net_id
resources:
  persistent_disk: 4096
  cloud_properties:
    instance_type: flavor
cloud:
  plugin: openstack
  properties:
    openstack:
      auth_url: auth_url
      username: username
      api_key: api_key
      tenant: tenant
      region: region
      endpoint_type: publicURL
      default_key_name: key_name
      default_security_groups:
      - security_group
      private_key: private_key_path
      state_timeout: 300
      wait_resource_poll_interval: 5
      connection_options:
        connect_timeout: 60
    registry:
      endpoint: http://admin:admin@localhost:25889
      user: admin
      password: admin
apply_spec:
  agent:
    blobstore:
      address: vip
    nats:
      address: vip
  properties:
    director:
      max_vm_create_tries: 15
YAML

        it 'generates the correct YAML' do
          expect(subject.to_h).to eq(Psych.load(expected_yml))
        end
      end

      context 'when BOSH_OPENSTACK_STATE_TIMEOUT is specified' do
        it 'uses given env variable value (converted to a float) as a state_timeout' do
          value = double('state_timeout', to_f: 'state_timeout_as_float')
          env.merge!('BOSH_OPENSTACK_STATE_TIMEOUT' => value)
          expect(subject.to_h['cloud']['properties']['openstack']['state_timeout']).to eq('state_timeout_as_float')
        end
      end

      context 'when BOSH_OPENSTACK_STATE_TIMEOUT is an empty string' do
        it 'uses 300 (number) as a state_timeout' do
          env.merge!('BOSH_OPENSTACK_STATE_TIMEOUT' => '')
          expect(subject.to_h['cloud']['properties']['openstack']['state_timeout']).to eq(300)
        end
      end

      context 'when BOSH_OPENSTACK_STATE_TIMEOUT is not specified' do
        it 'uses 300 (number) as a state_timeout' do
          env.delete('BOSH_OPENSTACK_STATE_TIMEOUT')
          expect(subject.to_h['cloud']['properties']['openstack']['state_timeout']).to eq(300)
        end
      end

      context 'when BOSH_OPENSTACK_CONNECTION_TIMEOUT is specified' do
        it 'uses given env variable value (converted to a float) as a connect_timeout' do
          value = double('connection_timeout', to_f: 'connection_timeout_as_float')
          env.merge!('BOSH_OPENSTACK_CONNECTION_TIMEOUT' => value)
          expect(subject.to_h['cloud']['properties']['openstack']['connection_options']['connect_timeout']).to eq('connection_timeout_as_float')
        end
      end

      context 'when BOSH_OPENSTACK_CONNECTION_TIMEOUT is an empty string' do
        it 'uses 60 (number) as a connect_timeout' do
          env.merge!('BOSH_OPENSTACK_CONNECTION_TIMEOUT' => '')
          expect(subject.to_h['cloud']['properties']['openstack']['connection_options']['connect_timeout']).to eq(60)
        end
      end

      context 'when BOSH_OPENSTACK_CONNECTION_TIMEOUT is not specified' do
        it 'uses 60 (number) as a connect_timeout' do
          env.delete('BOSH_OPENSTACK_CONNECTION_TIMEOUT')
          expect(subject.to_h['cloud']['properties']['openstack']['connection_options']['connect_timeout']).to eq(60)
        end
      end

      context 'when BOSH_OPENSTACK_DEFAULT_KEY_NAME is an empty string' do
        it 'uses jenkins as a default key name' do
          env.merge!('BOSH_OPENSTACK_DEFAULT_KEY_NAME' => '')
          expect(subject.to_h['cloud']['properties']['openstack']['default_key_name']).to eq('jenkins')
        end
      end

      context 'when BOSH_OPENSTACK_DEFAULT_KEY_NAME is not specified' do
        it 'uses jenkins as a default key name' do
          env.delete('BOSH_OPENSTACK_DEFAULT_KEY_NAME')
          expect(subject.to_h['cloud']['properties']['openstack']['default_key_name']).to eq('jenkins')
        end
      end

      context 'when BOSH_OPENSTACK_FLAVOR is not specified' do
        it 'uses m1.small as a default flavor' do
          env.delete('BOSH_OPENSTACK_FLAVOR')
          expect(subject.to_h['resources']['cloud_properties']['instance_type']).to eq('m1.small')
        end
      end

      context 'when BOSH_OPENSTACK_SECURITY_GROUP is not specified' do
        it 'uses default as the default security groups' do
          env.delete('BOSH_OPENSTACK_DEFAULT_SECURITY_GROUP')
          expect(subject.to_h['cloud']['properties']['openstack']['default_security_groups']).to eq(['default'])
        end
      end
    end

    its(:director_name) { should match(/microbosh-openstack-/) }

    describe '#cpi_options' do
      before do
        env.merge!(
          'BOSH_OPENSTACK_AUTH_URL' => 'fake-auth-url',
          'BOSH_OPENSTACK_USERNAME' => 'fake-username',
          'BOSH_OPENSTACK_API_KEY' => 'fake-api-key',
          'BOSH_OPENSTACK_TENANT' => 'fake-tenant',
          'BOSH_OPENSTACK_REGION' => 'fake-region',
          'BOSH_OPENSTACK_PRIVATE_KEY' => 'fake-private-key-path',
          'BOSH_OPENSTACK_DEFAULT_KEY_NAME' => 'key_name',
        )
      end

      it 'returns cpi options' do
        expect(subject.cpi_options).to eq(
          'openstack' => {
            'auth_url' => 'fake-auth-url',
            'username' => 'fake-username',
            'api_key' => 'fake-api-key',
            'tenant' => 'fake-tenant',
            'region' => 'fake-region',
            'endpoint_type' => 'publicURL',
            'default_key_name' => 'key_name',
            'default_security_groups' => ['default'],
            'private_key' => 'fake-private-key-path',
            'state_timeout' => 300,
            'wait_resource_poll_interval' => 5,
            'connection_options' => {
              'connect_timeout' => 60,
            }
          },
          'registry' => {
            'endpoint' => 'http://admin:admin@localhost:25889',
            'user' => 'admin',
            'password' => 'admin',
          },
        )
      end

      context 'when BOSH_OPENSTACK_REGISTRY_PORT is provided' do
        before do
          env.merge!('BOSH_OPENSTACK_REGISTRY_PORT' => '25880')
        end

        it 'sets the registry endpoint' do
          expect(subject.cpi_options['registry']['endpoint']).to eq('http://admin:admin@localhost:25880')
        end
      end
    end
  end
end
