require 'spec_helper'

describe 'cli: compiled_packages', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers

  with_reset_sandbox_before_each

  context 'when a release has been created' do
    let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }
    let(:release_tarball_path) do
      target_and_login
      output = runner.run('create release --with-tarball')
      matches = /^Release tarball \(.*\): (.*\.tgz)$/.match(output)
      old_path = matches[1]
      new_path = File.join(tmp_dir, 'release.tgz')
      FileUtils.cp(old_path, new_path)
      new_path
    end

    let(:tmp_dir) { Dir.mktmpdir }
    after { FileUtils.rm_r(tmp_dir) }

    it 'packages can be compiled, exported, and imported to a new director' do
      compile_packages_matcher = match(/compiling packages/i)

      # upload the provided release tarball
      target_and_login
      bosh_runner.run("upload release #{release_tarball_path}")
      upload_stemcell
      upload_cloud_config

      # deploy must compile the packages
      output = deploy_simple_manifest
      expect(output).to(compile_packages_matcher)

      # export the compiled packages into the provided dir
      output = bosh_runner.run("export compiled_packages bosh-release/0+dev.1 ubuntu-stemcell/1 #{tmp_dir}")
      matches = /^Exported compiled packages to `(.*\.tgz)'.$/.match(output)
      compiled_packages_tarball_path = matches[1]
      expect(File).to exist(compiled_packages_tarball_path)
      expect(compiled_packages_tarball_path).to start_with(tmp_dir)

      # reset the sandbox/director to delete previously compiled packages
      prepare_sandbox
      reset_sandbox

      # re-upload the provided release tarball
      target_and_login
      bosh_runner.run("upload release #{release_tarball_path}")
      upload_stemcell
      upload_cloud_config

      bosh_runner.run("import compiled_packages #{compiled_packages_tarball_path}")

      # deploying after importing all release packages should not compile again
      output = deploy_simple_manifest
      expect(output).to_not(compile_packages_matcher)
    end
  end

  it 'allows the user to import compiled packages after a previously successful import' do
    target_and_login

    cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
    bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")

    deployment_manifest = yaml_file('deployment_manifest', Bosh::Spec::Deployments.simple_manifest)
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
    Dir.chdir(ClientSandbox.test_release_dir) do
      FileUtils.rm_rf('dev_releases')
      output = bosh_runner.run_in_current_dir('create release --with-tarball')
      parse_release_tarball_path(output)
    end
  end
end
