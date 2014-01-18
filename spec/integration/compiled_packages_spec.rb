require 'spec_helper'

describe 'compiled_packages' do
  include IntegrationExampleGroup

  it 'allows user to export compiled packages after a deploy' do
    deploy_simple

    Dir.mktmpdir do |download_dir|
      run_bosh("export compiled_packages bosh-release/0.1-dev ubuntu-stemcell/1 #{download_dir}")

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
    run_bosh("deployment #{deployment_manifest.path}")
    run_bosh("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
    run_bosh("upload release #{create_release}")
    run_bosh("import compiled_packages #{spec_asset('bosh-release-0.1-dev-ubuntu-stemcell-1.tgz')}")

    deploy_output = run_bosh('deploy')
    expect(deploy_output).to_not match(/compiling packages/i)
  end

  it 'allows the user to import compiled packages after a previously successful import' do
    target_and_login

    deployment_manifest = yaml_file('simple_manifest', Bosh::Spec::Deployments.simple_manifest)
    run_bosh("deployment #{deployment_manifest.path}")
    run_bosh("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
    run_bosh("upload release #{create_release}")

    test_export = spec_asset('bosh-release-0.1-dev-ubuntu-stemcell-1.tgz')
    run_bosh("import compiled_packages #{test_export}")
    expect{ run_bosh("import compiled_packages #{test_export}") }.to_not raise_error

    deploy_output = run_bosh('deploy')
    expect(deploy_output).to_not match(/compiling packages/i)
  end

  def create_release
    Dir.chdir(TEST_RELEASE_DIR) do
      FileUtils.rm_rf('dev_releases')
      run_bosh('create release --with-tarball', work_dir: Dir.pwd)
    end
    File.join(TEST_RELEASE_DIR, 'dev_releases/bosh-release-0.1-dev.tgz')
  end
end
