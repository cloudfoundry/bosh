require 'spec_helper'

describe 'delete release', type: :integration do
  with_reset_sandbox_before_each

  # ~25s
  it 'allows deleting a whole release' do
    target_and_login

    release_filename = spec_asset('test_release.tgz')
    bosh_runner.run("upload release #{release_filename}")

    out = bosh_runner.run('delete release test_release')
    expect(out).to match regexp('Deleted `test_release')

    expect_output('releases', <<-OUT)
    No releases
    OUT
  end

  it 'can delete an uploaded compiled release (no source)' do
    target_and_login

    bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
    bosh_runner.run("upload release #{spec_asset('release-hello-go-50-on-toronto-os-stemcell-1.tgz')}")

    out = bosh_runner.run("delete release hello-go 50")
    expect(out).to match regexp("Started deleting packages > hello-go/b3df8c27c4525622aacc0d7013af30a9f2195393. Done")
    expect(out).to match regexp("Started deleting jobs > hello-go/0cf937b9a063cf96bd7506fa31699325b40d2d08. Done")
    expect(out).to match regexp('Deleted `hello-go/50')
  end

  # ~22s
  it 'allows deleting a particular release version' do
    target_and_login

    release_filename = spec_asset('test_release.tgz')
    bosh_runner.run("upload release #{release_filename}")

    out = bosh_runner.run('delete release test_release 1')
    expect(out).to match regexp('Deleted `test_release/1')
  end

  it 'fails to delete release in use but deletes a different release' do
    target_and_login

    Dir.chdir(ClientSandbox.test_release_dir) do
      bosh_runner.run_in_current_dir('create release')
      bosh_runner.run_in_current_dir('upload release')

      # change something in ClientSandbox.test_release_dir
      FileUtils.touch(File.join('src', 'bar', 'pretend_something_changed'))

      bosh_runner.run_in_current_dir('create release --force')
      bosh_runner.run_in_current_dir('upload release')
    end

    bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

    cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
    bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")

    deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.simple_manifest)
    bosh_runner.run("deployment #{deployment_manifest.path}")

    bosh_runner.run('deploy')

    out = bosh_runner.run('delete release bosh-release', failure_expected: true)
    expect(out).to match /Error 30007: Release `bosh-release' is still in use/

    out = bosh_runner.run('delete release bosh-release 0.2-dev')
    expect(out).to match %r{Deleted `bosh-release/0.2-dev'}
  end
end
