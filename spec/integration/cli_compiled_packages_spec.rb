require 'spec_helper'

describe 'cli: compiled_packages', type: :integration do
  with_reset_sandbox_before_each

  it 'allows user to export compiled packages after a deploy' do
    deploy_simple

    Dir.mktmpdir do |download_dir|
      bosh_runner.run("export compiled_packages bosh-release/0.1-dev ubuntu-stemcell/1 #{download_dir}")

      # Since import is not implemented yet we will inspect received tar file
      download_path = "#{download_dir}/bosh-release-0.1-dev-ubuntu-stemcell-1.tgz"
      result = Bosh::Exec.sh("tar -Oxzf '#{download_path}' compiled_packages.MF", on_error: :return)
      expect(result).to be_success

      bar_blobstore_id = YAML.load(result.output)["compiled_packages"].first["blobstore_id"]
      result = Bosh::Exec.sh("tar -Otzf '#{download_path}' compiled_packages/blobs/#{bar_blobstore_id} 2>/dev/null", on_error: :return)
      expect(result).to be_success
    end
  end

  it 'allows the user to import compiled packages' do
    target_and_login

    deployment_manifest = yaml_file('simple_manifest', Bosh::Spec::Deployments.simple_manifest)
    bosh_runner.run("deployment #{deployment_manifest.path}")
    bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
    bosh_runner.run("upload release #{create_release}")
    bosh_runner.run("import compiled_packages #{spec_asset('bosh-release-0.1-dev-ubuntu-stemcell-1.tgz')}")

    deploy_output = bosh_runner.run('deploy')
    expect(deploy_output).to_not match(/compiling packages/i)
  end

  it 'allows the user to import compiled packages after a previously successful import' do
    target_and_login

    deployment_manifest = yaml_file('simple_manifest', Bosh::Spec::Deployments.simple_manifest)
    bosh_runner.run("deployment #{deployment_manifest.path}")
    bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
    bosh_runner.run("upload release #{create_release}")

    test_export = spec_asset('bosh-release-0.1-dev-ubuntu-stemcell-1.tgz')
    bosh_runner.run("import compiled_packages #{test_export}")
    expect{ bosh_runner.run("import compiled_packages #{test_export}") }.to_not raise_error

    deploy_output = bosh_runner.run('deploy')
    expect(deploy_output).to_not match(/compiling packages/i)
  end

  def create_release
    Dir.chdir(TEST_RELEASE_DIR) do
      FileUtils.rm_rf('dev_releases')
      bosh_runner.run_in_current_dir('create release --with-tarball')
    end
    File.join(TEST_RELEASE_DIR, 'dev_releases/bosh-release-0+dev.1.tgz')
  end
end
