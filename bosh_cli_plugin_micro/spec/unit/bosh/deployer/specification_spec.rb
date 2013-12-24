require 'spec_helper'

describe Bosh::Deployer::Specification do
  let(:spec) { Bosh::Deployer::Specification.load_from_stemcell(spec_dir) }
  let(:spec_dir) { File.dirname(spec_asset('apply_spec.yml')) }

  before { Bosh::Deployer::Config.stub(agent_properties: agent_properties) }
  let(:agent_properties) { {} }

  before { Bosh::Deployer::Config.stub(spec_properties: spec_properties) }
  let(:spec_properties) { {} }

  it 'should load from file' do
    expect(spec.director_port).to eq 25555
  end

  it 'should update director address' do
    spec.update('1.1.1.1', '2.2.2.2')
    expect(spec.properties['director']['address']).to eq '2.2.2.2'
  end

  it 'should update blobstore address' do
    spec.update('1.1.1.1', '2.2.2.2')
    expect(spec.properties['agent']['blobstore']['address']).to eq '1.1.1.1'
  end

  it 'should update dns address' do
    spec.update('1.1.1.1', '2.2.2.2')
    expect(spec.properties['dns']['address']).to eq '1.1.1.1'
  end

  describe 'agent override' do
    let(:agent_properties) { { 'blobstore' => { 'address' => '3.3.3.3' } } }
    let(:spec_properties) { { 'ntp' => %w[1.2.3.4] } }

    it 'should update blobstore address' do
      spec.update('1.1.1.1', '2.2.2.2')
      expect(spec.properties['agent']['blobstore']['address']).to eq '3.3.3.3'
    end

    it 'should update ntp server list' do
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
