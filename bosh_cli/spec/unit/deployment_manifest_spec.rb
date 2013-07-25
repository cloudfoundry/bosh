require 'spec_helper'
require 'cli/deployment_manifest'

describe Bosh::Cli::DeploymentManifest do
  let(:manifest_hash) do
    {
      'networks' => [
        {
          'name' => 'fake network',
          'subnets' => [
            {
              'range' => 'fake range'
            }
          ],
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
end
