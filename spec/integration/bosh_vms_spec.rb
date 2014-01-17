require 'spec_helper'

describe 'vms list' do
  include IntegrationExampleGroup

  it 'should return vms in a deployment' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['releases'].first['version'] = 'latest'

    deploy_simple(manifest_hash: manifest_hash)

    vms = run_bosh('vms')
    expect(vms).to match /foobar\/0/
    expect(vms).to match /foobar\/1/
    expect(vms).to match /foobar\/2/
    expect(vms).to match /VMs total: 3/
  end
end
