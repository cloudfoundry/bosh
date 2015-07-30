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

  it 'deployment fails when starting task fails' do
    deploy_from_scratch
    director.vm('foobar/0').fail_start_task
    _, exit_code = deploy(failure_expected: true, return_exit_code: true)
    expect(exit_code).to_not eq(0)
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

  context 'it supports compiled releases' do
    context 'when older compiled and newer non-compiled (source release) versions of the same release are uploaded' do
      before {
        target_and_login

        bosh_runner.run("upload stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")

        cloud_config_with_centos = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config_with_centos['resource_pools'][0]['stemcell']['name'] = 'bosh-aws-xen-hvm-centos-7-go_agent'
        cloud_config_with_centos['resource_pools'][0]['stemcell']['version'] = '3001'
        upload_cloud_config(:cloud_config_hash => cloud_config_with_centos)

        bosh_runner.run("upload release #{spec_asset('compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.tgz')}")
      }

      context 'and they contain identical packages' do
        before {
          bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-4-same-packages-as-1.tgz')}")
          deployment_manifest = Bosh::Spec::Deployments.test_deployment_manifest_with_job('job_using_pkg_5')
          deployment_manifest['releases'][0]['version'] = '4'
          set_deployment({manifest_hash: deployment_manifest })
        }

        it 'does not compile any packages' do
          out = deploy({})

          expect(out).to_not include("Started compiling packages")
        end
      end

      context 'and they contain one different package' do
        before {
          bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-3-pkg1-updated.tgz')}")
          deployment_manifest = Bosh::Spec::Deployments.test_deployment_manifest_with_job('job_using_pkg_5')
          deployment_manifest['releases'][0]['version'] = '3'
          set_deployment({manifest_hash: deployment_manifest })
        }

        xit 'compiles only the package with the different version and those that depend on it' do
          out = deploy({})
          expect(out).to include("Started compiling packages > pkg_1/b0fe23fce97e2dc8fd9da1035dc637ecd8fc0a0f")
          expect(out).to include('Started compiling packages > pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4')

          expect(out).to_not include('Started compiling packages > pkg_2/')
          expect(out).to_not include('Started compiling packages > pkg_3_depends_on_2/')
          expect(out).to_not include('Started compiling packages > pkg_4_depends_on_3/')
        end
      end
    end
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
