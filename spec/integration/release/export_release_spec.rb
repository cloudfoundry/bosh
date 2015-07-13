require 'spec_helper'

describe 'export release', type: :integration do
  with_reset_sandbox_before_each

  before{
    target_and_login
    upload_cloud_config

    bosh_runner.run("upload release #{spec_asset('valid_release.tgz')}")
    bosh_runner.run("upload release #{spec_asset('valid_release_2.tgz')}")
    bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
    bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell_2.tgz')}")
    set_deployment({manifest_hash: Bosh::Spec::Deployments.multiple_release_manifest})
    deploy({})
  }

  it 'compiles all packages of the release against the requested stemcell' do
    out = bosh_runner.run("export release appcloud/0.1 toronto-os/1")
    expect(out).to match /Started compiling packages/
    expect(out).to match /Started compiling packages > mutator\/2.99.7. Done/
    expect(out).to match /Started compiling packages > stuff\/0.1.17. Done/
    expect(out).to match /Task ([0-9]+) done/
  end

  it 'does not compile packages that were already compiled' do
    bosh_runner.run("export release appcloud/0.1 toronto-os/1")
    out = bosh_runner.run("export release appcloud/0.1 toronto-os/1")
    expect(out).to_not match /Started compiling packages/
    expect(out).to_not match /Started compiling packages > mutator\/2.99.7. Done/
    expect(out).to_not match /Started compiling packages > stuff\/0.1.17. Done/
    expect(out).to match /Task ([0-9]+) done/
  end

  it 'compiles any release that is in the targeted deployment' do
    out = bosh_runner.run("export release appcloud_2/0.2 toronto-os/1")
    expect(out).to match /Started compiling packages/
    expect(out).to match /Started compiling packages > mutator_2\/2.99.8. Done/
    expect(out).to match /Started compiling packages > stuff_2\/0.1.18. Done/
    expect(out).to match /Task ([0-9]+) done/
  end

  it 'compiles against a stemcell that is not in the resource pool of the targeted deployment' do
    out = bosh_runner.run("export release appcloud/0.1 toronto-centos/2")

    expect(out).to match /Started compiling packages/
    expect(out).to match /Started compiling packages > mutator\/2.99.7. Done/
    expect(out).to match /Started compiling packages > stuff\/0.1.17. Done/
    expect(out).to match /Task ([0-9]+) done/
  end

  it 'returns an error when the release does not exist' do
    expect {
      bosh_runner.run("export release app/1 toronto-os/1")
    }.to raise_error(RuntimeError, /Error 30005: Release `app' doesn't exist/)
  end

  it 'returns an error when the release version does not exist' do
    expect {
      bosh_runner.run("export release appcloud/1 toronto-os/1")
    }.to raise_error(RuntimeError, /Error 30006: Release version `appcloud\/1' doesn't exist/)
  end

  it 'returns an error when the stemcell os and version does not exist' do
    expect {
      bosh_runner.run("export release appcloud/0.1 nonexistos/1")
    }.to raise_error(RuntimeError, /Error 50003: Stemcell version `1' for OS `nonexistos' doesn't exist/)
  end

  it 'puts a tarball in the blobstore' do
    Dir.chdir(ClientSandbox.test_release_dir) do
      File.open('config/final.yml', 'w') do |final|
        final.puts YAML.dump(
             'blobstore' => {
                 'provider' => 'local',
                 'options' => { 'blobstore_path' => current_sandbox.blobstore_storage_dir },
             },
         )
      end
    end

    out = bosh_runner.run("export release appcloud/0.1 toronto-os/1")
    task_id = out[/\d+/].to_i

    result_file = File.open(current_sandbox.sandbox_path("boshdir/tasks/#{task_id}/result"), "r")
    tarball_data = Yajl::Parser.parse(result_file.read)

    files = Dir.entries(current_sandbox.blobstore_storage_dir)
    expect(files).to include(tarball_data['blobstore_id'])

    Dir.mktmpdir do |temp_dir|
      tarball_path = File.join(current_sandbox.blobstore_storage_dir, tarball_data['blobstore_id'])
      `tar xzf #{tarball_path} -C #{temp_dir}`
      files = Dir.entries(temp_dir)
      expect(files).to include("compiled_packages","compiled_release.MF","jobs")
    end
  end
end
