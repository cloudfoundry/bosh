require 'spec_helper'

describe 'deploy', type: :integration do
  with_reset_sandbox_before_each

  it 'allows removing deployed jobs and adding new jobs at the same time' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['name'] = 'fake-name1'
    deploy_from_scratch(manifest_hash: manifest_hash)
    expect_running_vms(%w(fake-name1/0 fake-name1/1 fake-name1/2))

    manifest_hash['jobs'].first['name'] = 'fake-name2'
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(fake-name2/0 fake-name2/1 fake-name2/2))

    manifest_hash['jobs'].first['name'] = 'fake-name1'
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(fake-name1/0 fake-name1/1 fake-name1/2))
  end

  context 'when using legacy deployment configuration' do
    let(:legacy_manifest_hash ) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest.merge(Bosh::Spec::Deployments.simple_cloud_config)
      manifest_hash['resource_pools'].find{ |i| i['name'] == 'a' }['size'] = 5
      manifest_hash
    end

    before do
      target_and_login
      create_and_upload_test_release
      upload_stemcell
    end

    context 'when a could config is uploaded' do
      it 'returns an error if deployment manifest contains cloud properties' do
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config_hash['resource_pools'].find{ |i| i['name'] == 'a' }['size'] = 4

        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        output = deploy_simple_manifest(manifest_hash: legacy_manifest_hash, failure_expected: true)
        expect(output).to include('Deployment manifest should not contain cloud config properties')
      end
    end

    context 'when no cloud config is uploaded' do
      it 'respects the cloud related configurations in the deployment manifest' do
        deploy_simple_manifest(manifest_hash: legacy_manifest_hash)

        expect_running_vms(%w(foobar/0 foobar/1 foobar/2 unknown/unknown unknown/unknown))
        expect_output('deployments', <<-OUT)
          +--------+----------------------+-------------------+--------------+
          | Name   | Release(s)           | Stemcell(s)       | Cloud Config |
          +--------+----------------------+-------------------+--------------+
          | simple | bosh-release/0+dev.1 | ubuntu-stemcell/1 | none         |
          +--------+----------------------+-------------------+--------------+

          Deployments total: 1
        OUT
      end
    end
  end

  it 'supports scaling down and then scaling up' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config

    cloud_config_hash['resource_pools'].first['size'] = 3
    manifest_hash['jobs'].first['instances'] = 3
    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 foobar/1 foobar/2))

    # scale down
    cloud_config_hash['resource_pools'].first['size'] = 2
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    manifest_hash['jobs'].first['instances'] = 2
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 foobar/1))

    # scale up, above original size
    cloud_config_hash['resource_pools'].first['size'] = 4
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    manifest_hash['jobs'].first['instances'] = 4
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 foobar/1 foobar/2 foobar/3))
  end

  it 'supports fixed size resource pools' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['resource_pools'].first['size'] = 3

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 3

    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
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
    cloud_config_hash['resource_pools'].first['size'] = 4
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    manifest_hash['jobs'].first['instances'] = 4
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 foobar/1 foobar/2 foobar/3))
  end

  it 'supports dynamically sized resource pools' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['resource_pools'].first.delete('size')

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 3

    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
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
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['resource_pools'].first['size'] = 2

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1

    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0 unknown/unknown))

    cloud_config_hash['resource_pools'].first.delete('size')
    upload_cloud_config(cloud_config_hash: cloud_config_hash)
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0))
  end

  def expect_running_vms(job_name_index_list)
    vms = director.vms
    check_for_unknowns(vms)
    expect(vms.map(&:job_name_index)).to match_array(job_name_index_list)
    expect(vms.map(&:last_known_state).uniq).to eq(['running'])
  end

  def check_for_unknowns(vms)
    uniq_vm_names = vms.map(&:job_name_index).uniq
    if uniq_vm_names.size == 1 && uniq_vm_names.first == 'unknown/unknown'
      bosh_runner.print_agent_debug_logs(vms.first.agent_id)
    end
  end
end
