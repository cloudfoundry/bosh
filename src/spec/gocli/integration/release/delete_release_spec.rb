require_relative '../../spec_helper'

describe 'delete release', type: :integration do
  with_reset_sandbox_before_each

  # ~25s
  it 'allows deleting a whole release' do
    release_filename = spec_asset('test_release.tgz')
    bosh_runner.run("upload-release #{release_filename}")

    out = bosh_runner.run('delete-release test_release')
    expect(out).to match /Succeeded/

    expect(table(bosh_runner.run('releases', json: true))).to eq([])
  end

  it 'can delete an uploaded compiled release (no source)' do
    bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")
    bosh_runner.run("upload-release #{spec_asset('release-hello-go-50-on-toronto-os-stemcell-1.tgz')}")

    out = bosh_runner.run("delete-release hello-go/50")
    expect(out).to match /Deleting packages: hello-go\/b3df8c27c4525622aacc0d7013af30a9f2195393 \(\d{2}:\d{2}:\d{2}\)/
    expect(out).to match /Deleting jobs: hello-go\/0cf937b9a063cf96bd7506fa31699325b40d2d08 \(\d{2}:\d{2}:\d{2}\)/
    expect(out).to match /Succeeded/
  end

  # ~22s
  it 'allows deleting a particular release version' do
    release_filename = spec_asset('test_release.tgz')
    bosh_runner.run("upload-release #{release_filename}")

    out = bosh_runner.run('delete-release test_release/1')
    expect(out).to match /Succeeded/
  end

  it 'fails to delete release in use but deletes a different release' do
    Dir.chdir(ClientSandbox.test_release_dir) do
      bosh_runner.run_in_current_dir('create-release')
      bosh_runner.run_in_current_dir('upload-release')

      # change something in ClientSandbox.test_release_dir
      FileUtils.touch(File.join('src', 'bar', 'pretend_something_changed'))

      bosh_runner.run_in_current_dir('create-release --force')
      bosh_runner.run_in_current_dir('upload-release')
    end

    bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")

    upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
    deploy_simple_manifest(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups, deployment_name: 'simple')

    out = bosh_runner.run('delete-release bosh-release', failure_expected: true)
    expect(out).to match /Error: Release 'bosh-release' is still in use/

    out = bosh_runner.run('delete-release bosh-release/0.2-dev')
    expect(out).to match /Succeeded/
  end
end
