require 'spec_helper'
require 'bosh/dev/bat/deployment_manifest'
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
  end
end
