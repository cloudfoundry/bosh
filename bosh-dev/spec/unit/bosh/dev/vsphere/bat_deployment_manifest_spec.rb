require 'spec_helper'
require 'bosh/dev/vsphere/bat_deployment_manifest'
require 'bosh/stemcell/archive'
require 'bosh/dev/bat/director_uuid'

module Bosh::Dev::VSphere
  describe BatDeploymentManifest do
    let(:input_yaml_manual) do
      <<-EOF
---
cpi: vsphere
properties:
  second_static_ip: fake-second-ip
  pool_size: 1
  instances: 1
  networks:
  - name: static
    static_ip: ip
    type: manual
    cidr: net_cidr
    reserved:
      - reserved1
      - reserved2
    static:
      - net_static
    gateway: net_gateway
    vlan: net_id
EOF
    end

    subject(:manifest) { BatDeploymentManifest.load(input_yaml_manual) }
    let(:director_uuid) { instance_double('Bosh::Dev::Bat::DirectorUuid', value: 'director-uuid') }
    let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', version: 13, name: 'stemcell-name') }

    its(:filename) { should eq ('bat.yml') }

    it 'is a deployment manifest' do
      expect(manifest).to be_a(Bosh::Dev::Bat::DeploymentManifest)
      expect(manifest).to be_a(Bosh::Dev::VSphere::BatDeploymentManifest)
    end

    describe 'load' do
      it 'returns a new BatDeploymentManifest with the parsed yaml content' do
        expect(BatDeploymentManifest.load(input_yaml_manual)).to be_an_instance_of(BatDeploymentManifest)
      end
    end

    describe 'load_from_file' do
      let!(:bat_deployment_config_file) { Tempfile.new(['bat_deployment_config', '.yml']) }
      before { File.open(bat_deployment_config_file.path, 'w') { |file| file.write(input_yaml_manual) } }
      after { bat_deployment_config_file.delete }

      it 'reads the file from the path and loads it' do
        expect(
          BatDeploymentManifest.load_from_file(bat_deployment_config_file.path)
        ).to eq(
          BatDeploymentManifest.load(input_yaml_manual)
        )
      end
    end

    describe 'validate' do
      it 'does not complain about valid manual network yaml' do
        expect{ BatDeploymentManifest.load(input_yaml_manual).validate }.to_not raise_error
      end

      it 'requires cpi to be vsphere' do
        new_yaml = update_yaml(input_yaml_manual) do |yaml_hash|
          yaml_hash['cpi'] = 'something-else'
        end
        manifest = BatDeploymentManifest.load(new_yaml)

        expect{ manifest.validate }.to raise_error(Membrane::SchemaValidationError)
      end

      it 'requires properties.networks.name to be static' do
        new_yaml = update_yaml(input_yaml_manual) do |yaml_hash|
          yaml_hash['properties']['networks'][0]['name'] = 'not-static'
        end
        manifest = BatDeploymentManifest.load(new_yaml)

        expect{ manifest.validate }.to raise_error(Membrane::SchemaValidationError)
      end

      it 'requires properties.networks.vlan' do
        new_yaml = update_yaml(input_yaml_manual) do |yaml_hash|
          yaml_hash['properties']['networks'][0].delete('vlan')
        end
        manifest = BatDeploymentManifest.load(new_yaml)

        expect{ manifest.validate }.to raise_error(Membrane::SchemaValidationError)
      end
    end

    def update_yaml(yaml_string)
      yaml_hash = YAML.load(yaml_string)
      yield(yaml_hash)
      YAML.dump(yaml_hash)
    end
  end
end
