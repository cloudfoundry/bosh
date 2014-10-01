require 'spec_helper'
require 'bosh/dev/openstack/bat_deployment_manifest'
require 'bosh/stemcell/archive'
require 'bosh/dev/bat/director_uuid'

module Bosh::Dev::Openstack
  describe BatDeploymentManifest do
    let(:input_yaml_manual) do
      <<-EOF
---
cpi: openstack
properties:
  vip: vip
  second_static_ip: fake-second-static-ip
  pool_size: 1
  flavor_with_no_ephemeral_disk: no-ephemeral
  instances: 1
  networks:
  - name: default
    static_ip: fake-static-ip
    type: manual
    cloud_properties:
      net_id: net_id
      security_groups:
      - default
    cidr: net_cidr
    reserved:
    - net_reserved
    static:
    - net_static
    gateway: net_gateway
  - name: second
    static_ip: fake-second-network-static-ip
    type: manual
    cloud_properties:
      net_id: second_net_id
      security_groups:
      - default
    cidr: second_net_cidr
    reserved:
    - second_net_reserved
    static:
    - second_net_static
    gateway: second_net_gateway
EOF
    end
    let(:input_yaml_dynamic) do
      <<-EOF
---
cpi: openstack
properties:
  vip: vip
  pool_size: 1
  flavor_with_no_ephemeral_disk: no-ephemeral
  instances: 1
  networks:
  - name: default
    type: dynamic
    cloud_properties:
      net_id: net_id
      security_groups:
      - default
EOF
    end

    subject(:manifest) { BatDeploymentManifest.load(input_yaml_dynamic) }
    let(:director_uuid) { instance_double('Bosh::Dev::Bat::DirectorUuid', value: 'director-uuid') }
    let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', version: 13, name: 'stemcell-name') }

    its(:filename) { should eq ('bat.yml') }

    it 'is a deployment manifest' do
      expect(manifest).to be_a(Bosh::Dev::Bat::DeploymentManifest)
      expect(manifest).to be_a(Bosh::Dev::Openstack::BatDeploymentManifest)
    end

    describe 'load' do
      it 'returns a new BatDeploymentManifest with the parsed yaml content' do
        expect(BatDeploymentManifest.load(input_yaml_dynamic)).to be_an_instance_of(BatDeploymentManifest)
      end
    end

    describe 'load_from_file' do
      let!(:bat_deployment_config_file) { Tempfile.new(['bat_deployment_config', '.yml']) }
      before { File.open(bat_deployment_config_file.path, 'w') { |file| file.write(input_yaml_dynamic) } }
      after { bat_deployment_config_file.delete }

      it 'reads the file from the path and loads it' do
        expect(
          BatDeploymentManifest.load_from_file(bat_deployment_config_file.path)
        ).to eq(
          BatDeploymentManifest.load(input_yaml_dynamic)
        )
      end
    end

    describe 'validate' do
      it 'does not complain about valid manual network yaml' do
        manifest = BatDeploymentManifest.load(input_yaml_manual)
        manifest.net_type = 'manual'
        expect{ manifest.validate }.to_not raise_error
      end

      it 'does not complain about valid dynamic network yaml' do
        # defaults to dynamic net_type
        expect{ BatDeploymentManifest.load(input_yaml_dynamic).validate }.to_not raise_error
      end

      it 'optionally allows properties.key_name' do
        new_yaml = update_yaml(input_yaml_dynamic) do |yaml_hash|
          yaml_hash['properties'].delete('key_name')
        end
        manifest = BatDeploymentManifest.load(new_yaml)

        expect{ manifest.validate }.to_not raise_error

        new_yaml = update_yaml(input_yaml_dynamic) do |yaml_hash|
          yaml_hash['properties']['key_name'] = 'bosh'
        end
        manifest = BatDeploymentManifest.load(new_yaml)

        expect{ manifest.validate }.to_not raise_error
      end

      it 'requires cpi to be openstack' do
        new_yaml = update_yaml(input_yaml_dynamic) do |yaml_hash|
          yaml_hash['cpi'] = 'something-else'
        end
        manifest = BatDeploymentManifest.load(new_yaml)

        expect{ manifest.validate }.to raise_error(Membrane::SchemaValidationError)
      end

      it 'requires properties.vip' do
        new_yaml = update_yaml(input_yaml_dynamic) do |yaml_hash|
          yaml_hash['properties'].delete('vip')
        end
        manifest = BatDeploymentManifest.load(new_yaml)

        expect{ manifest.validate }.to raise_error(Membrane::SchemaValidationError)
      end

      it 'requires properties.flavor_with_no_ephemeral_disk' do
        new_yaml = update_yaml(input_yaml_dynamic) do |yaml_hash|
          yaml_hash['properties'].delete('flavor_with_no_ephemeral_disk')
        end
        manifest = BatDeploymentManifest.load(new_yaml)

        expect{ manifest.validate }.to raise_error(Membrane::SchemaValidationError)
      end

      it 'requires properties.networks.cloud_properties.security_groups' do
        new_yaml = update_yaml(input_yaml_dynamic) do |yaml_hash|
          yaml_hash['properties']['networks'][0]['cloud_properties'].delete('security_groups')
        end
        manifest = BatDeploymentManifest.load(new_yaml)

        expect{ manifest.validate }.to raise_error(Membrane::SchemaValidationError)
      end

      context 'when the net_type is manual' do
        it 'requires properties.networks.cloud_properties.net_id' do
          new_yaml = update_yaml(input_yaml_manual) do |yaml_hash|
            yaml_hash['properties']['networks'][0]['cloud_properties'].delete('net_id')
          end
          manifest = BatDeploymentManifest.load(new_yaml)

          expect{ manifest.validate }.to raise_error(Membrane::SchemaValidationError)
        end
      end

      context 'when the net_type is dynamic' do
        it 'optionally allows properties.networks.cloud_properties.net_id' do
          new_yaml = update_yaml(input_yaml_dynamic) do |yaml_hash|
            yaml_hash['properties']['networks'][0]['cloud_properties'].delete('net_id')
          end
          manifest = BatDeploymentManifest.load(new_yaml)

          expect{ manifest.validate }.to_not raise_error

          new_yaml = update_yaml(input_yaml_dynamic) do |yaml_hash|
            yaml_hash['properties']['networks'][0]['cloud_properties']['net_id'] = 'net_id'
          end
          manifest = BatDeploymentManifest.load(new_yaml)

          expect{ manifest.validate }.to_not raise_error
        end
      end
    end

    def update_yaml(yaml_string)
      yaml_hash = YAML.load(yaml_string)
      yield(yaml_hash)
      YAML.dump(yaml_hash)
    end
  end
end
