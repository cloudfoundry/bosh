require 'spec_helper'

describe Bosh::Deployer::Specification do
  subject(:spec) do
    Bosh::Deployer::Specification.new(spec_hash, config)
  end
  let(:spec_hash) { YAML.load_file(spec_asset('apply_spec.yml')) }

  let(:agent_properties) { {} }
  let(:spec_properties) { {} }

  let(:config) do
    instance_double(
      'Bosh::Deployer::Configuration',
      name: nil,
      agent_properties: agent_properties,
      spec_properties: spec_properties,
    )
  end

  describe '.load_from_stemcell' do
    let(:spec) { Bosh::Deployer::Specification.load_from_stemcell(spec_dir, config) }
    let(:spec_dir) { File.dirname(spec_asset('apply_spec.yml')) }

    it 'loads from file' do
      expect(spec.director_port).to eq 25555
    end
  end

  context 'when the agent services are included in the apply_spec' do
    let(:services) { %w{blobstore nats} }

    before do
      spec_hash['properties']['agent'] ||= {}
      services.each do |service|
        spec_hash['properties']['agent'][service] ||= {}
      end
    end

    it 'updates the agent service addresses' do
      spec.update('1.1.1.1', '2.2.2.2')
      services.each do |service|
        expect(spec.properties['agent'][service]['address']).to eq '1.1.1.1'
      end
    end
  end

  context 'when the agent services are not included in the apply_spec' do
    let(:services) { %w{blobstore nats} }

    before do
      spec_hash['properties']['agent'] ||= {}
      services.each do |service|
        spec_hash['properties']['agent'].delete(service)
      end
    end

    it 'updates the agent service addresses' do
      spec.update('1.1.1.1', '2.2.2.2')
      services.each do |service|
        expect(spec.properties['agent'][service]['address']).to eq '1.1.1.1'
      end
    end
  end

  context 'when the services are included in the apply_spec' do
    let(:agent_services) { %w{registry dns} }
    let(:internal_services) { %w{director redis blobstore nats} }

    before do
      (agent_services + internal_services).each do |service|
        spec_hash['properties'][service] ||= {}
      end
    end

    it 'updates the service addresses to the internal services ip' do
      spec.update('1.1.1.1', '2.2.2.2')

      agent_services.each do |service|
        expect(spec.properties[service]['address']).to eq '1.1.1.1'
      end
      internal_services.each do |service|
        expect(spec.properties[service]['address']).to eq '2.2.2.2'
      end
    end
  end

  context 'when there are services not included in the apply_spec' do
    let(:services) { %w{director redis blobstore nats registry dns} }

    before do
      services.each do |service|
        spec_hash['properties'].delete(service)
      end
    end

    it 'does not update service addresses for services not included in apply_spec.yml' do
      spec.update('1.1.1.1', '2.2.2.2')

      services.each do |service|
        expect(spec.properties).to_not have_key(service)
      end
    end
  end

  describe 'agent override' do
    let(:agent_properties) { { 'blobstore' => { 'address' => '3.3.3.3' } } }
    let(:spec_properties) { { 'ntp' => %w[1.2.3.4] } }

    it 'updates blobstore address with agent_properties override' do
      spec.update('1.1.1.1', '2.2.2.2')
      expect(spec.properties['agent']['blobstore']['address']).to eq '3.3.3.3'
    end

    it 'updates ntp server list with spec_properties override' do
      spec.update('1.1.1.1', '2.2.2.2')
      expect(spec.properties['ntp']).to eq %w[1.2.3.4]
    end
  end

  describe 'compiled package cache' do
    let(:spec_properties) do
      {
        'compiled_package_cache' => {
          'bucket' => 'foo',
          'access_key_id' => 'bar',
          'secret_access_key' => 'baz'
        }
      }
    end

    it 'should update the apply spec if enabled in micro_bosh.yml apply_spec' do
      spec.update('1.1.1.1', '2.2.2.2')
      expect(spec.properties['compiled_package_cache']).to eq(
        spec_properties['compiled_package_cache'])
    end
  end

  describe 'director ssl' do
    let(:spec_properties) do
      {
        'director' => {
          'ssl' => {
            'cert' => 'foo-cert',
            'key' => 'baz-key'
          }
        }
      }
    end

    it 'updates the apply spec with ssl key and cert' do
      spec.update('1.1.1.1', '2.2.2.2')
      expect(spec.properties['director']['ssl']).to eq(spec_properties['director']['ssl'])
      expect(spec.properties['director']['ssl']).to_not be_nil
    end
  end
end
