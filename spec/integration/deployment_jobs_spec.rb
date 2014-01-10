require 'spec_helper'

describe 'deployment job control' do
  include IntegrationExampleGroup

  it 'allows to scale up and down a job via manifest' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['resource_pools'].first['size'] = 3
    manifest_hash['jobs'].first['instances'] = 3
    deploy_simple(manifest_hash: manifest_hash)
    expect_to_have_running_job_indices(%w(foobar/0 foobar/1 foobar/2))

    manifest_hash['resource_pools'].first['size'] = 2
    manifest_hash['jobs'].first['instances'] = 2
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_to_have_running_job_indices(%w(foobar/0 foobar/1))

    manifest_hash['resource_pools'].first['size'] = 4
    manifest_hash['jobs'].first['instances'] = 4
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_to_have_running_job_indices(%w(foobar/0 foobar/1 foobar/2 foobar/3))
  end

  it 'allows to remove previously deployed job and add new job at the same time via a manifest' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['name'] = 'fake-name1'
    deploy_simple(manifest_hash: manifest_hash)
    expect_to_have_running_job_indices(%w(fake-name1/0 fake-name1/1 fake-name1/2))

    manifest_hash['jobs'].first['name'] = 'fake-name2'
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_to_have_running_job_indices(%w(fake-name2/0 fake-name2/1 fake-name2/2))

    manifest_hash['jobs'].first['name'] = 'fake-name1'
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_to_have_running_job_indices(%w(fake-name1/0 fake-name1/1 fake-name1/2))
  end

  it 'restarts a job' do
    deploy_simple
    expect(run_bosh('restart foobar 0')).to match %r{foobar/0 has been restarted}
  end

  it 'recreates a job' do
    deploy_simple
    expect(run_bosh('recreate foobar 1')).to match %r{foobar/1 has been recreated}
  end

  def expect_to_have_running_job_indices(job_indicies)
    vms = get_vms
    expect(vms.map { |d| d[:job_index] }).to match_array(job_indicies)
    expect(vms.map { |d| d[:state] }.uniq).to eq(['running'])
  end
end
