require 'spec_helper'
require 'cli/deployment_manifest'

describe Bosh::Cli::DeploymentManifest do
  let(:manifest_hash) do
    {
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
            'name' => 'fake-stemcell',
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

  context 'when stemcell version is an integer' do
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
