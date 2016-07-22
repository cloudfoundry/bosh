require 'spec_helper'
require 'cli/deployment_manifest'

describe Bosh::Cli::DeploymentManifest do
  let(:manifest_hash) do
    {
      'stemcells' => [
        {
          'name' => 'fake-stemcell-v2-manifest',
          'version' => 12321
        }
      ],
      'releases' => [
        {
          'name' => 'fake-release',
          'version' => 456
        }
      ],
      'networks' => [
        {
          'name' => 'fake network',
          'subnets' => [
            {
              'range' => 'fake range'
            }
          ],
        }
      ],
      'resource_pools' => [
        {
          'name' => 'fake-resource-pool',
          'stemcell' => {
            'name' => 'fake-stemcell-v1-manifest',
            'version' => 12321
          }
        }
      ]
    }
  end

  subject do
    Bosh::Cli::DeploymentManifest.new(manifest_hash)
  end

  it "doesn't modify the provided manifest hash" do
    expect {
      subject.normalize
    }.not_to change { manifest_hash['networks'].first['subnets'] }
  end

  context 'when stemcell version is an integer in a v2 manifest' do
    it 'converts it to string' do
      normalized = subject.normalize
      expect(normalized['stemcells'].first['version']).to eq('12321')
    end
  end

  context 'when stemcell version is an integer in a v1 manifest' do
    it 'converts it to string' do
      normalized = subject.normalize
      expect(normalized['resource_pools']['fake-resource-pool']['stemcell']['version']).to eq('12321')
    end
  end

  context 'when release version is an integer' do
    it 'converts it to string' do
      normalized = subject.normalize
      expect(normalized['releases']['fake-release']['version']).to eq('456')
    end
  end
end
