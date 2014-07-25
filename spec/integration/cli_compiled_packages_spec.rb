require 'spec_helper'

describe 'cli: compiled_packages', type: :integration do
  with_reset_sandbox_before_each

  it 'compiled packages can be exported and imported to a new director' do
    compile_packages_matcher = match(/compiling packages/i)

    output = deploy_simple
    expect(output).to(compile_packages_matcher)

    Dir.mktmpdir do |download_dir|
      download_path = "#{download_dir}/bosh-release-0.1-dev-ubuntu-stemcell-1.tgz"

      output = bosh_runner.run("export compiled_packages bosh-release/0.1-dev ubuntu-stemcell/1 #{download_dir}")
      expect(output).to include("Exported compiled packages to `#{download_path}'")
      expect(File).to exist(download_path)

      reset_sandbox('resetting director to import compiled packages')

      target_and_login
      upload_release
      upload_stemcell
      bosh_runner.run("import compiled_packages #{download_path}")
   end

    output = deploy_simple_manifest
    expect(output).to_not(compile_packages_matcher)
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
