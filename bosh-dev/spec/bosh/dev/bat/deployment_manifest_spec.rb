require 'spec_helper'
require 'bosh/dev/openstack/bat_deployment_manifest'
require 'bosh/stemcell/archive'
require 'psych'
require 'bosh/dev/bat/director_uuid'
require 'bosh/stemcell/archive'

module Bosh::Dev::Bat
  describe DeploymentManifest do
    let(:input_yaml_manual) do
      <<-EOF
---
cpi: fake-cpi
properties:
  second_static_ip: fake-second-static-ip
  pool_size: 1
  instances: 1
  networks:
  - name: default
    static_ip: fake-static-ip
    type: manual
    cidr: net_cidr
    reserved:
    - net_reserved
    static:
    - net_static
    gateway: net_gateway
EOF
    end

    let(:input_yaml_dynamic) do
      <<-EOF
---
cpi: fake-cpi
properties:
  pool_size: 1
  instances: 1
  networks:
  - name: default
    type: dynamic
EOF
    end

    subject(:manifest) { DeploymentManifest.load(input_yaml_dynamic) }
    let(:director_uuid) { instance_double('Bosh::Dev::Bat::DirectorUuid', value: 'director-uuid') }
    let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', version: 13, name: 'stemcell-name') }

    its(:filename) { should eq ('bat.yml') }

    it 'is writable' do
      expect(manifest).to be_a(Bosh::Dev::WritableManifest)
    end

    describe 'load' do
      it 'returns a new BatDeploymentManifest with the parsed yaml content' do
        expect(DeploymentManifest.load(input_yaml_dynamic)).to be_an_instance_of(DeploymentManifest)
      end
    end

    describe 'load_from_file' do
      let!(:bat_deployment_config_file) { Tempfile.new(['bat_deployment_config', '.yml']) }
      before { File.open(bat_deployment_config_file.path, 'w') { |file| file.write(input_yaml_dynamic) } }
      after { bat_deployment_config_file.delete }

      it 'reads the file from the path and loads it' do
        expect(
          DeploymentManifest.load_from_file(bat_deployment_config_file.path)
        ).to eq(
          DeploymentManifest.load(input_yaml_dynamic)
        )
      end
    end

    describe 'validate' do
      it 'does not complain about valid manual yaml' do
        manifest = DeploymentManifest.load(input_yaml_manual)
        manifest.net_type = 'manual'
        expect{ manifest.validate }.to_not raise_error
      end

      it 'does not complain about valid dynamic yaml' do
        # dynamic networking is default
        expect{ DeploymentManifest.load(input_yaml_dynamic).validate }.to_not raise_error
      end

      it 'expects the specified network types to match the ones in the parsed yaml' do
        manifest = DeploymentManifest.load(input_yaml_dynamic)
        manifest.net_type = 'manual'
        expect{ manifest.validate }.to raise_error(Membrane::SchemaValidationError)

        manifest = DeploymentManifest.load(input_yaml_manual)
        manifest.net_type = 'dynamic'
        expect{ manifest.validate }.to raise_error(Membrane::SchemaValidationError)
      end

      it 'does not complain when stemcell is provided' do
        manifest = DeploymentManifest.load(input_yaml_dynamic)
        manifest.stemcell = stemcell_archive
        expect{ manifest.validate }.to_not raise_error
      end

      it 'requires properties.networks.cidr when manual' do
        requires_network_property_when_manual('cidr')
      end

      it 'requires properties.networks.reserved when manual' do
        requires_network_property_when_manual('reserved')
      end

      it 'requires properties.networks.static when manual' do
        requires_network_property_when_manual('static')
      end

      it 'requires properties.networks.gateway when manual' do
        requires_network_property_when_manual('gateway')
      end

      def requires_network_property_when_manual(property_name)
        new_yaml = update_yaml(input_yaml_dynamic) do |yaml_hash|
          yaml_hash['properties']['networks'].each do |network|
            network['type'] = 'manual'
            network.delete(property_name)
          end
        end
        manifest = DeploymentManifest.load(new_yaml)
        manifest.net_type = 'manual'

        expect{ manifest.validate }.to raise_error(Membrane::SchemaValidationError)
      end
    end

    describe '#net_type' do
      it 'sets the net_type' do
        manifest.net_type = 'manual'
        expect(manifest.net_type).to eq('manual')
      end
    end

    describe '#stemcell' do
      it 'sets the stemcell properties' do
        manifest_hash = manifest.to_h
        expect(manifest_hash['properties']).to_not include('stemcell')

        manifest.stemcell = stemcell_archive

        manifest_hash = manifest.to_h
        expect(manifest_hash['properties']).to include('stemcell')
        expect(manifest_hash['properties']['stemcell']['name']).to eq('stemcell-name')
        expect(manifest_hash['properties']['stemcell']['version']).to eq(13)
      end
    end

    describe '#director_uuid' do
      it 'sets the uuid property' do
        manifest_hash = manifest.to_h
        expect(manifest_hash['properties']).to_not include('uuid')

        manifest.director_uuid = director_uuid

        manifest_hash = manifest.to_h
        expect(manifest_hash['properties']['uuid']).to eq('director-uuid')
      end
    end

    describe '#to_h' do
      it 'returns a hash' do
        expect(manifest.to_h).to be_an_instance_of(Hash)
      end

      it 'includes the director uuid' do
        manifest.director_uuid = director_uuid

        manifest_hash = manifest.to_h
        expect(manifest_hash['properties']).to include('uuid')
      end

      it 'includes the stemcell reference' do
        manifest.stemcell = stemcell_archive

        manifest_hash = manifest.to_h
        expect(manifest_hash['properties']).to include('stemcell')
      end
    end

    def update_yaml(yaml_string)
      yaml_hash = YAML.load(yaml_string)
      yield(yaml_hash)
      YAML.dump(yaml_hash)
    end
  end
end
