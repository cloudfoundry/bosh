require 'spec_helper'

describe 'deploy', type: :integration do
  with_reset_sandbox_before_each

  it 'allows removing deployed jobs and adding new jobs at the same time' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['name'] = 'fake-name1'
    deploy_simple(manifest_hash: manifest_hash)
    expect_running_vms(%w(fake-name1/0 fake-name1/1 fake-name1/2))

    manifest_hash['jobs'].first['name'] = 'fake-name2'
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(fake-name2/0 fake-name2/1 fake-name2/2))

    manifest_hash['jobs'].first['name'] = 'fake-name1'
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(fake-name1/0 fake-name1/1 fake-name1/2))
  end

  it 'supports scaling down and then scaling up' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest

    manifest_hash['resource_pools'].first['size'] = 3
    manifest_hash['jobs'].first['instances'] = 3
    deploy_simple(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 foobar/1 foobar/2))

    # scale down
    manifest_hash['resource_pools'].first['size'] = 2
    manifest_hash['jobs'].first['instances'] = 2
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 foobar/1))

    # scale up, above original size
    manifest_hash['resource_pools'].first['size'] = 4
    manifest_hash['jobs'].first['instances'] = 4
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 foobar/1 foobar/2 foobar/3))
  end

  it 'supports fixed size resource pools' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest

    manifest_hash['resource_pools'].first['size'] = 3
    manifest_hash['jobs'].first['instances'] = 3
    deploy_simple(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 foobar/1 foobar/2))

    # scale down
    manifest_hash['jobs'].first['instances'] = 1
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 unknown/unknown unknown/unknown))

    # scale up, below original size
    manifest_hash['jobs'].first['instances'] = 2
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 foobar/1 unknown/unknown))

    # scale up, above original size
    manifest_hash['resource_pools'].first['size'] = 4
    manifest_hash['jobs'].first['instances'] = 4
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 foobar/1 foobar/2 foobar/3))
  end

  it 'supports dynamically sized resource pools' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest

    manifest_hash['resource_pools'].first.delete('size')
    manifest_hash['jobs'].first['instances'] = 3
    deploy_simple(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 foobar/1 foobar/2))

    # scale down
    manifest_hash['jobs'].first['instances'] = 1
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0))

    # scale up, below original size
    manifest_hash['jobs'].first['instances'] = 2
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 foobar/1))

    # scale up, above original size
    manifest_hash['jobs'].first['instances'] = 4
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 foobar/1 foobar/2 foobar/3))
  end

  it 'deletes extra vms when switching from fixed-size to dynamically-sized resource pools' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest

    manifest_hash['resource_pools'].first['size'] = 2
    manifest_hash['jobs'].first['instances'] = 1

    deploy_simple(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 unknown/unknown))

    manifest_hash['resource_pools'].first.delete('size')
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0))
  end

  def expect_running_vms(job_name_index_list)
    vms = director.vms
    expect(vms.map(&:job_name_index)).to match_array(job_name_index_list)
    expect(vms.map(&:last_known_state).uniq).to eq(['running'])
  end
end
