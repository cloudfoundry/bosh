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

        expect_running_vms(%w(foobar/0 foobar/1 foobar/2))
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

  it 'ignores the now deprecated resource_pools.size property' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['resource_pools'].first['size'] = 2

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1

    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
    expect_running_vms(%w(foobar/0)) # no unknown/unknown
  end


  it 'outputs properly formatted deploy information' do
    # We need to keep this test since the output is not tested and
    # keeps breaking.

    output = deploy_from_scratch

    duration_regex = '\\d\\d:\\d\\d:\\d\\d'
    step_duration_regex = '\\(' + duration_regex + '\\)'
    date_regex = '\\d\\d\\d\\d-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d UTC'
    sha_regex = '[0-9a-z]+'
    task_regex = '\\d+'

    # order for creating missing vms is not guaranteed (running in parallel)
    expect(output).to match(<<-OUT)
Director task #{task_regex}
  Started preparing deployment
  Started preparing deployment > Binding deployment. Done #{step_duration_regex}
  Started preparing deployment > Binding releases. Done #{step_duration_regex}
  Started preparing deployment > Binding existing deployment. Done #{step_duration_regex}
  Started preparing deployment > Binding stemcells. Done #{step_duration_regex}
  Started preparing deployment > Binding templates. Done #{step_duration_regex}
  Started preparing deployment > Binding properties. Done #{step_duration_regex}
  Started preparing deployment > Binding unallocated VMs. Done #{step_duration_regex}
     Done preparing deployment #{step_duration_regex}

  Started preparing package compilation > Finding packages to compile. Done #{step_duration_regex}

  Started compiling packages
  Started compiling packages > foo/#{sha_regex}. Done #{step_duration_regex}
  Started compiling packages > bar/#{sha_regex}. Done #{step_duration_regex}
     Done compiling packages #{step_duration_regex}

  Started preparing networks > Binding networks. Done #{step_duration_regex}

  Started preparing dns > Binding DNS. Done #{step_duration_regex}

  Started binding links > foobar. Done #{step_duration_regex}

  Started creating missing vms
  Started creating missing vms > foobar/0
  Started creating missing vms > foobar/1
  Started creating missing vms > foobar/2
     Done creating missing vms > foobar/\\d #{step_duration_regex}
     Done creating missing vms > foobar/\\d #{step_duration_regex}
     Done creating missing vms > foobar/\\d #{step_duration_regex}
     Done creating missing vms #{step_duration_regex}

  Started updating job foobar
  Started updating job foobar > foobar/0 \\(canary\\). Done #{step_duration_regex}
  Started updating job foobar > foobar/1 \\(canary\\). Done #{step_duration_regex}
  Started updating job foobar > foobar/2. Done #{step_duration_regex}
     Done updating job foobar #{step_duration_regex}

Task #{task_regex} done

Started		#{date_regex}
Finished	#{date_regex}
Duration	#{duration_regex}

Deployed `simple' to `Test Director'
    OUT
  end
end
